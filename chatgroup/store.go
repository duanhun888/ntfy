package chatgroup

import (
	"crypto/sha256"
	"database/sql"
	"encoding/hex"
	"fmt"
	"path/filepath"
	"strings"

	"heckel.io/ntfy/v2/db"
	"heckel.io/ntfy/v2/util"
)

// Store persists groups, members and bots
type Store struct {
	db      *db.DB
	queries queries
	ownsDB  bool
}

type queries struct {
	insertGroup                  string
	selectGroupByID              string
	selectGroupsForUser          string
	selectAllGroups              string
	deleteGroup                  string
	insertMember                 string
	selectMember                 string
	selectMembers                string
	deleteMember                 string
	deleteMembersByGroup         string
	countMembers                 string
	insertBot                    string
	selectBotByID                string
	selectBotByToken             string
	selectBotsByGroup            string
	deleteBot                    string
	deleteBotsByGroup            string
	insertRoute                  string
	selectRouteByID              string
	selectRouteByBizType         string
	selectRoutesForUser          string
	selectAllRoutes              string
	updateRoute                  string
	deleteRoute                  string
	updateMemberRole             string
	insertDelivery               string
	selectDeliveriesForUser      string
	selectAllDeliveries          string
	selectDeliveryStats          string
	selectDeliveryStatsUser      string
	insertFriendRequest          string
	selectFriendRequestByID      string
	selectPendingRequest         string
	selectIncomingFriendRequests string
	selectOutgoingFriendRequests string
	updateFriendRequestStatus    string
	insertFriendship             string
	selectFriendship             string
	selectFriendsForUser         string
	selectFriendshipTopic        string
	updateFriendshipTopic        string
	deleteFriendship             string
}

// CreateGroup creates a group owned by ownerUserID with an internal topic
func (s *Store) CreateGroup(name, ownerUserID, topic string) (*Group, error) {
	name = strings.TrimSpace(name)
	if name == "" || ownerUserID == "" || topic == "" {
		return nil, ErrInvalidArgument
	}
	g := &Group{
		ID:          util.RandomStringPrefix(groupIDPrefix, groupIDLength),
		Name:        name,
		OwnerUserID: ownerUserID,
		Topic:       topic,
		Created:     NowUnix(),
		MemberCount: 1,
		Role:        RoleOwner,
	}
	err := db.ExecTx(s.db, func(tx *sql.Tx) error {
		if _, err := tx.Exec(s.queries.insertGroup, g.ID, g.Name, g.OwnerUserID, g.Topic, g.Created); err != nil {
			return err
		}
		if _, err := tx.Exec(s.queries.insertMember, g.ID, ownerUserID, string(RoleOwner), g.Created); err != nil {
			return err
		}
		return nil
	})
	if err != nil {
		return nil, err
	}
	return g, nil
}

// Group returns a group by ID
func (s *Store) Group(id string) (*Group, error) {
	var g Group
	err := s.db.QueryRow(s.queries.selectGroupByID, id).Scan(&g.ID, &g.Name, &g.OwnerUserID, &g.Topic, &g.Created)
	if err == sql.ErrNoRows {
		return nil, ErrNotFound
	} else if err != nil {
		return nil, err
	}
	_ = s.db.QueryRow(s.queries.countMembers, id).Scan(&g.MemberCount)
	return &g, nil
}

// GroupsForUser lists groups the user belongs to
func (s *Store) GroupsForUser(userID string) ([]*Group, error) {
	rows, err := s.db.Query(s.queries.selectGroupsForUser, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := make([]*Group, 0)
	for rows.Next() {
		var g Group
		var role string
		if err := rows.Scan(&g.ID, &g.Name, &g.OwnerUserID, &g.Topic, &g.Created, &role, &g.MemberCount); err != nil {
			return nil, err
		}
		g.Role = Role(role)
		out = append(out, &g)
	}
	return out, rows.Err()
}

// AllGroups lists every group (admin use)
func (s *Store) AllGroups() ([]*Group, error) {
	rows, err := s.db.Query(s.queries.selectAllGroups)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := make([]*Group, 0)
	for rows.Next() {
		var g Group
		if err := rows.Scan(&g.ID, &g.Name, &g.OwnerUserID, &g.Topic, &g.Created, &g.MemberCount); err != nil {
			return nil, err
		}
		out = append(out, &g)
	}
	return out, rows.Err()
}

// DeleteGroup removes a group and cascading members/bots
func (s *Store) DeleteGroup(id string) error {
	return db.ExecTx(s.db, func(tx *sql.Tx) error {
		if _, err := tx.Exec(s.queries.deleteBotsByGroup, id); err != nil {
			return err
		}
		if _, err := tx.Exec(s.queries.deleteMembersByGroup, id); err != nil {
			return err
		}
		res, err := tx.Exec(s.queries.deleteGroup, id)
		if err != nil {
			return err
		}
		n, _ := res.RowsAffected()
		if n == 0 {
			return ErrNotFound
		}
		return nil
	})
}

// MemberRole returns the caller's role in the group
func (s *Store) MemberRole(groupID, userID string) (Role, error) {
	var role string
	err := s.db.QueryRow(s.queries.selectMember, groupID, userID).Scan(&role)
	if err == sql.ErrNoRows {
		return "", ErrForbidden
	} else if err != nil {
		return "", err
	}
	return Role(role), nil
}

// AddMember adds a member to a group
func (s *Store) AddMember(groupID, userID string, role Role) error {
	if role == "" {
		role = RoleMember
	}
	_, err := s.db.Exec(s.queries.insertMember, groupID, userID, string(role), NowUnix())
	if err != nil {
		if strings.Contains(strings.ToLower(err.Error()), "unique") || strings.Contains(strings.ToLower(err.Error()), "constraint") {
			return ErrAlreadyMember
		}
		return err
	}
	return nil
}

// RemoveMember removes a member
func (s *Store) RemoveMember(groupID, userID string) error {
	res, err := s.db.Exec(s.queries.deleteMember, groupID, userID)
	if err != nil {
		return err
	}
	n, _ := res.RowsAffected()
	if n == 0 {
		return ErrNotFound
	}
	return nil
}

// UpdateMemberRole sets a member's role to admin or member (not owner).
func (s *Store) UpdateMemberRole(groupID, userID string, role Role) error {
	if role != RoleAdmin && role != RoleMember {
		return fmt.Errorf("%w: role must be admin or member", ErrInvalidArgument)
	}
	g, err := s.Group(groupID)
	if err != nil {
		return err
	}
	if userID == g.OwnerUserID {
		return fmt.Errorf("%w: cannot change owner role", ErrInvalidArgument)
	}
	current, err := s.MemberRole(groupID, userID)
	if err != nil {
		return err
	}
	if current == RoleOwner {
		return fmt.Errorf("%w: cannot change owner role", ErrInvalidArgument)
	}
	res, err := s.db.Exec(s.queries.updateMemberRole, string(role), groupID, userID)
	if err != nil {
		return err
	}
	n, _ := res.RowsAffected()
	if n == 0 {
		return ErrNotFound
	}
	return nil
}

// InsertDelivery records an alert trigger attempt.
func (s *Store) InsertDelivery(d *AlertDelivery) error {
	if d == nil || d.RouteID == "" || d.BizType == "" || d.OwnerUserID == "" {
		return ErrInvalidArgument
	}
	if d.ID == "" {
		d.ID = util.RandomStringPrefix(deliveryIDPrefix, deliveryIDLength)
	}
	if d.Created == 0 {
		d.Created = NowUnix()
	}
	d.Message = truncateRunes(d.Message, deliveryMsgMax)
	var appOK, wecomOK any
	if d.AppOK != nil {
		if *d.AppOK {
			appOK = 1
		} else {
			appOK = 0
		}
	}
	if d.WeComOK != nil {
		if *d.WeComOK {
			wecomOK = 1
		} else {
			wecomOK = 0
		}
	}
	_, err := s.db.Exec(s.queries.insertDelivery, d.ID, d.RouteID, d.BizType, d.OwnerUserID, d.Message, appOK, wecomOK, nullIfEmpty(d.WeComError), d.Created)
	return err
}

// DeliveriesForUser lists recent deliveries for routes owned by userID.
func (s *Store) DeliveriesForUser(userID string, limit int, bizType string) ([]*AlertDelivery, error) {
	if limit <= 0 || limit > 500 {
		limit = 100
	}
	bizType = strings.TrimSpace(bizType)
	rows, err := s.db.Query(s.queries.selectDeliveriesForUser, userID, bizType, bizType, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	return scanDeliveries(rows)
}

// AllDeliveries lists recent deliveries (admin).
func (s *Store) AllDeliveries(limit int, bizType string) ([]*AlertDelivery, error) {
	if limit <= 0 || limit > 500 {
		limit = 100
	}
	bizType = strings.TrimSpace(bizType)
	rows, err := s.db.Query(s.queries.selectAllDeliveries, bizType, bizType, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	return scanDeliveries(rows)
}

// DeliveryStatsSince returns total/failed counts since unix timestamp.
func (s *Store) DeliveryStatsSince(since int64, userID string) (*DeliveryStats, error) {
	var stats DeliveryStats
	var err error
	if userID == "" {
		err = s.db.QueryRow(s.queries.selectDeliveryStats, since).Scan(&stats.Total, &stats.Failed)
	} else {
		err = s.db.QueryRow(s.queries.selectDeliveryStatsUser, since, userID).Scan(&stats.Total, &stats.Failed)
	}
	if err != nil {
		return nil, err
	}
	return &stats, nil
}

func scanDeliveries(rows *sql.Rows) ([]*AlertDelivery, error) {
	out := make([]*AlertDelivery, 0)
	for rows.Next() {
		var d AlertDelivery
		var appOK, wecomOK sql.NullInt64
		var wecomErr sql.NullString
		if err := rows.Scan(&d.ID, &d.RouteID, &d.BizType, &d.OwnerUserID, &d.Message, &appOK, &wecomOK, &wecomErr, &d.Created); err != nil {
			return nil, err
		}
		if appOK.Valid {
			v := appOK.Int64 != 0
			d.AppOK = &v
		}
		if wecomOK.Valid {
			v := wecomOK.Int64 != 0
			d.WeComOK = &v
		}
		if wecomErr.Valid {
			d.WeComError = wecomErr.String
		}
		out = append(out, &d)
	}
	return out, rows.Err()
}

func truncateRunes(s string, max int) string {
	if max <= 0 || s == "" {
		return s
	}
	r := []rune(s)
	if len(r) <= max {
		return s
	}
	return string(r[:max])
}

// Members lists group members
func (s *Store) Members(groupID string) ([]*Member, error) {
	rows, err := s.db.Query(s.queries.selectMembers, groupID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := make([]*Member, 0)
	for rows.Next() {
		var m Member
		var role string
		if err := rows.Scan(&m.UserID, &role, &m.Joined); err != nil {
			return nil, err
		}
		m.Role = Role(role)
		out = append(out, &m)
	}
	return out, rows.Err()
}

// CreateBot creates a webhook bot; Token is returned in full only here
func (s *Store) CreateBot(groupID, name string) (*Bot, error) {
	name = strings.TrimSpace(name)
	if name == "" || groupID == "" {
		return nil, ErrInvalidArgument
	}
	b := &Bot{
		ID:      util.RandomStringPrefix(botIDPrefix, botIDLength),
		GroupID: groupID,
		Name:    name,
		Token:   util.RandomLowerStringPrefix(tokenPrefix, tokenLength),
		Created: NowUnix(),
	}
	if _, err := s.db.Exec(s.queries.insertBot, b.ID, b.GroupID, b.Name, b.Token, b.Created); err != nil {
		return nil, err
	}
	b.TokenHint = tokenHint(b.Token)
	return b, nil
}

// Bots lists bots for a group (without full tokens)
func (s *Store) Bots(groupID string) ([]*Bot, error) {
	rows, err := s.db.Query(s.queries.selectBotsByGroup, groupID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := make([]*Bot, 0)
	for rows.Next() {
		var b Bot
		var token string
		if err := rows.Scan(&b.ID, &b.GroupID, &b.Name, &token, &b.Created); err != nil {
			return nil, err
		}
		b.TokenHint = tokenHint(token)
		out = append(out, &b)
	}
	return out, rows.Err()
}

// Bot returns a bot by ID
func (s *Store) Bot(botID string) (*Bot, error) {
	var b Bot
	var token string
	err := s.db.QueryRow(s.queries.selectBotByID, botID).Scan(&b.ID, &b.GroupID, &b.Name, &token, &b.Created)
	if err == sql.ErrNoRows {
		return nil, ErrNotFound
	} else if err != nil {
		return nil, err
	}
	b.TokenHint = tokenHint(token)
	return &b, nil
}

// DeleteBot deletes a bot
func (s *Store) DeleteBot(botID string) error {
	res, err := s.db.Exec(s.queries.deleteBot, botID)
	if err != nil {
		return err
	}
	n, _ := res.RowsAffected()
	if n == 0 {
		return ErrNotFound
	}
	return nil
}

// LookupBotToken resolves a webhook token to bot + group topic
func (s *Store) LookupBotToken(token string) (*BotWithGroup, error) {
	var b BotWithGroup
	err := s.db.QueryRow(s.queries.selectBotByToken, token).Scan(
		&b.ID, &b.GroupID, &b.Name, &b.Token, &b.Created, &b.Topic, &b.OwnerUserID,
	)
	if err == sql.ErrNoRows {
		return nil, ErrNotFound
	} else if err != nil {
		return nil, err
	}
	return &b, nil
}

// CreateAlertRoute creates a business-type alert route.
func (s *Store) CreateAlertRoute(bizType, name, ownerUserID, groupID, wecomWebhook string) (*AlertRoute, error) {
	bizType = strings.TrimSpace(bizType)
	name = strings.TrimSpace(name)
	groupID = strings.TrimSpace(groupID)
	wecomWebhook = strings.TrimSpace(wecomWebhook)
	if bizType == "" || name == "" || ownerUserID == "" {
		return nil, ErrInvalidArgument
	}
	if groupID == "" && wecomWebhook == "" {
		return nil, fmt.Errorf("%w: group_id or wecom_webhook required", ErrInvalidArgument)
	}
	if !validBizType(bizType) {
		return nil, fmt.Errorf("%w: invalid biz_type", ErrInvalidArgument)
	}
	r := &AlertRoute{
		ID:           util.RandomStringPrefix(routeIDPrefix, routeIDLength),
		BizType:      bizType,
		Name:         name,
		Token:        util.RandomLowerStringPrefix(routeTokenPrefix, routeTokenLength),
		GroupID:      groupID,
		WeComWebhook: wecomWebhook,
		Enabled:      true,
		OwnerUserID:  ownerUserID,
		Created:      NowUnix(),
	}
	enabled := 1
	if _, err := s.db.Exec(s.queries.insertRoute, r.ID, r.BizType, r.Name, r.Token, nullIfEmpty(r.GroupID), nullIfEmpty(r.WeComWebhook), enabled, r.OwnerUserID, r.Created); err != nil {
		if strings.Contains(strings.ToLower(err.Error()), "unique") {
			return nil, fmt.Errorf("%w: biz_type already exists", ErrInvalidArgument)
		}
		return nil, err
	}
	r.TokenHint = tokenHint(r.Token)
	return r, nil
}

// AlertRoute returns a route by ID (no full token).
func (s *Store) AlertRoute(id string) (*AlertRoute, error) {
	return s.scanRoute(s.db.QueryRow(s.queries.selectRouteByID, id), false)
}

// AlertRouteByBizType returns a route by business type (includes full token for auth check).
func (s *Store) AlertRouteByBizType(bizType string) (*AlertRoute, error) {
	return s.scanRoute(s.db.QueryRow(s.queries.selectRouteByBizType, bizType), true)
}

// AlertRoutesForUser lists routes owned by user (or all if admin lists via AllAlertRoutes).
func (s *Store) AlertRoutesForUser(userID string) ([]*AlertRoute, error) {
	rows, err := s.db.Query(s.queries.selectRoutesForUser, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	return s.scanRoutes(rows)
}

// AllAlertRoutes lists every route (admin).
func (s *Store) AllAlertRoutes() ([]*AlertRoute, error) {
	rows, err := s.db.Query(s.queries.selectAllRoutes)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	return s.scanRoutes(rows)
}

// UpdateAlertRoute updates mutable fields. Empty token fields are unchanged.
func (s *Store) UpdateAlertRoute(id, name, groupID, wecomWebhook string, enabled bool) (*AlertRoute, error) {
	name = strings.TrimSpace(name)
	groupID = strings.TrimSpace(groupID)
	wecomWebhook = strings.TrimSpace(wecomWebhook)
	if name == "" {
		return nil, ErrInvalidArgument
	}
	if groupID == "" && wecomWebhook == "" {
		return nil, fmt.Errorf("%w: group_id or wecom_webhook required", ErrInvalidArgument)
	}
	en := 0
	if enabled {
		en = 1
	}
	res, err := s.db.Exec(s.queries.updateRoute, name, nullIfEmpty(groupID), nullIfEmpty(wecomWebhook), en, id)
	if err != nil {
		return nil, err
	}
	n, _ := res.RowsAffected()
	if n == 0 {
		return nil, ErrNotFound
	}
	return s.AlertRoute(id)
}

// DeleteAlertRoute deletes a route.
func (s *Store) DeleteAlertRoute(id string) error {
	res, err := s.db.Exec(s.queries.deleteRoute, id)
	if err != nil {
		return err
	}
	n, _ := res.RowsAffected()
	if n == 0 {
		return ErrNotFound
	}
	return nil
}

func (s *Store) scanRoutes(rows *sql.Rows) ([]*AlertRoute, error) {
	out := make([]*AlertRoute, 0)
	for rows.Next() {
		r, err := scanRouteRow(rows, false)
		if err != nil {
			return nil, err
		}
		out = append(out, r)
	}
	return out, rows.Err()
}

func (s *Store) scanRoute(row *sql.Row, includeToken bool) (*AlertRoute, error) {
	r, err := scanRouteRow(row, includeToken)
	if err == sql.ErrNoRows {
		return nil, ErrNotFound
	}
	return r, err
}

type rowScanner interface {
	Scan(dest ...any) error
}

func scanRouteRow(row rowScanner, includeToken bool) (*AlertRoute, error) {
	var r AlertRoute
	var token string
	var groupID, wecom sql.NullString
	var enabled int
	err := row.Scan(&r.ID, &r.BizType, &r.Name, &token, &groupID, &wecom, &enabled, &r.OwnerUserID, &r.Created)
	if err != nil {
		return nil, err
	}
	if groupID.Valid {
		r.GroupID = groupID.String
	}
	if wecom.Valid {
		r.WeComWebhook = wecom.String
	}
	r.Enabled = enabled != 0
	r.TokenHint = tokenHint(token)
	if includeToken {
		r.Token = token
	}
	return &r, nil
}

func nullIfEmpty(s string) any {
	if s == "" {
		return nil
	}
	return s
}

func validBizType(s string) bool {
	if len(s) < 1 || len(s) > 64 {
		return false
	}
	for _, c := range s {
		if (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') || c == '_' || c == '-' {
			continue
		}
		return false
	}
	return true
}

// GenerateTopic returns a unique-ish internal topic name
func GenerateTopic() string {
	return util.RandomStringPrefix(topicPrefix, topicLength)
}

// GenerateDMTopic returns a deterministic private-chat topic for two users.
func GenerateDMTopic(userA, userB string) string {
	low, high := orderedUserPair(userA, userB)
	sum := sha256.Sum256([]byte(low + "\x00" + high))
	// 14 hex chars → "d_" + 14 = 16, AllowedTopic charset
	return dmTopicPrefix + hex.EncodeToString(sum[:7])
}

func tokenHint(token string) string {
	if len(token) <= 4 {
		return token
	}
	return "…" + token[len(token)-4:]
}

// SQLiteFilename derives chatgroup.db next to the auth file
func SQLiteFilename(authFile string) string {
	dir := filepath.Dir(authFile)
	return filepath.Join(dir, "chatgroup.db")
}

// EnsureTopicAllowed validates topic length for ntfy
func EnsureTopicAllowed(topic string) error {
	if len(topic) < 1 || len(topic) > 64 {
		return fmt.Errorf("%w: topic length", ErrInvalidArgument)
	}
	return nil
}

func orderedUserPair(a, b string) (low, high string) {
	if a < b {
		return a, b
	}
	return b, a
}

// AreFriends returns true if the two users are friends.
func (s *Store) AreFriends(userA, userB string) (bool, error) {
	low, high := orderedUserPair(userA, userB)
	var n int
	err := s.db.QueryRow(s.queries.selectFriendship, low, high).Scan(&n)
	if err == sql.ErrNoRows {
		return false, nil
	} else if err != nil {
		return false, err
	}
	return n > 0, nil
}

// ListFriends returns friendships for userID (other party IDs + created + DM topic).
func (s *Store) ListFriends(userID string) ([]*Friend, error) {
	out, err := s.listFriendsRows(userID)
	if err != nil && isMissingTopicColumn(err) {
		// Older DBs that skipped v4→v5: add column then retry.
		if _, alterErr := s.db.Exec(`ALTER TABLE friendship ADD COLUMN topic TEXT NOT NULL DEFAULT ''`); alterErr != nil && !isDuplicateColumn(alterErr) {
			return nil, err
		}
		out, err = s.listFriendsRows(userID)
	}
	if err != nil {
		return nil, err
	}
	// Backfill DM topics AFTER closing the cursor. Nested queries while iterating
	// SQLite rows lock the connection and surface as HTTP 500 to clients.
	for _, f := range out {
		if f.Topic != "" {
			continue
		}
		t, err := s.ensureFriendshipTopic(userID, f.UserID)
		if err != nil {
			return nil, err
		}
		f.Topic = t
	}
	return out, nil
}

func (s *Store) listFriendsRows(userID string) ([]*Friend, error) {
	rows, err := s.db.Query(s.queries.selectFriendsForUser, userID, userID, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := make([]*Friend, 0)
	for rows.Next() {
		var f Friend
		var topic sql.NullString
		if err := rows.Scan(&f.UserID, &f.Created, &topic); err != nil {
			return nil, err
		}
		f.Topic = topic.String
		out = append(out, &f)
	}
	return out, rows.Err()
}

func isMissingTopicColumn(err error) bool {
	if err == nil {
		return false
	}
	lower := strings.ToLower(err.Error())
	return (strings.Contains(lower, "no such column") || strings.Contains(lower, "undefined column")) &&
		strings.Contains(lower, "topic")
}

func isDuplicateColumn(err error) bool {
	if err == nil {
		return false
	}
	return strings.Contains(strings.ToLower(err.Error()), "duplicate column")
}

// CreateFriendRequest creates a pending request from fromUserID to toUserID.
func (s *Store) CreateFriendRequest(fromUserID, toUserID string) (*FriendRequest, error) {
	if fromUserID == "" || toUserID == "" || fromUserID == toUserID {
		return nil, ErrInvalidArgument
	}
	friends, err := s.AreFriends(fromUserID, toUserID)
	if err != nil {
		return nil, err
	}
	if friends {
		return nil, ErrAlreadyFriends
	}
	var existingID string
	err = s.db.QueryRow(s.queries.selectPendingRequest, fromUserID, toUserID).Scan(&existingID)
	if err == nil && existingID != "" {
		return nil, ErrAlreadyRequested
	} else if err != nil && err != sql.ErrNoRows {
		return nil, err
	}
	// Also block if reverse pending exists — caller should accept instead
	err = s.db.QueryRow(s.queries.selectPendingRequest, toUserID, fromUserID).Scan(&existingID)
	if err == nil && existingID != "" {
		return nil, fmt.Errorf("%w: reverse request pending, accept instead", ErrAlreadyRequested)
	} else if err != nil && err != sql.ErrNoRows {
		return nil, err
	}
	req := &FriendRequest{
		ID:         util.RandomStringPrefix(friendRequestIDPrefix, friendRequestIDLength),
		FromUserID: fromUserID,
		ToUserID:   toUserID,
		Status:     FriendRequestPending,
		Created:    NowUnix(),
	}
	if _, err := s.db.Exec(s.queries.insertFriendRequest, req.ID, req.FromUserID, req.ToUserID, req.Status, req.Created); err != nil {
		return nil, err
	}
	return req, nil
}

// FriendRequest returns a request by ID.
func (s *Store) FriendRequest(id string) (*FriendRequest, error) {
	var r FriendRequest
	err := s.db.QueryRow(s.queries.selectFriendRequestByID, id).Scan(
		&r.ID, &r.FromUserID, &r.ToUserID, &r.Status, &r.Created,
	)
	if err == sql.ErrNoRows {
		return nil, ErrNotFound
	} else if err != nil {
		return nil, err
	}
	return &r, nil
}

// ListFriendRequests lists incoming or outgoing requests for userID.
// box is "incoming" or "outgoing"; if statusFilter is non-empty, only that status is returned.
func (s *Store) ListFriendRequests(userID, box, statusFilter string) ([]*FriendRequest, error) {
	var rows *sql.Rows
	var err error
	switch box {
	case "incoming":
		rows, err = s.db.Query(s.queries.selectIncomingFriendRequests, userID, statusFilter, statusFilter)
	case "outgoing":
		rows, err = s.db.Query(s.queries.selectOutgoingFriendRequests, userID, statusFilter, statusFilter)
	default:
		return nil, ErrInvalidArgument
	}
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := make([]*FriendRequest, 0)
	for rows.Next() {
		var r FriendRequest
		if err := rows.Scan(&r.ID, &r.FromUserID, &r.ToUserID, &r.Status, &r.Created); err != nil {
			return nil, err
		}
		out = append(out, &r)
	}
	return out, rows.Err()
}

// AcceptFriendRequest marks the request accepted and creates friendship. Only the recipient may accept.
// Returns the DM topic shared by both users.
func (s *Store) AcceptFriendRequest(requestID, actorUserID string) (topic string, err error) {
	req, err := s.FriendRequest(requestID)
	if err != nil {
		return "", err
	}
	if req.ToUserID != actorUserID {
		return "", ErrForbidden
	}
	if req.Status != FriendRequestPending {
		return "", ErrInvalidArgument
	}
	low, high := orderedUserPair(req.FromUserID, req.ToUserID)
	topic = GenerateDMTopic(req.FromUserID, req.ToUserID)
	err = db.ExecTx(s.db, func(tx *sql.Tx) error {
		if _, err := tx.Exec(s.queries.updateFriendRequestStatus, FriendRequestAccepted, requestID); err != nil {
			return err
		}
		if _, err := tx.Exec(s.queries.insertFriendship, low, high, NowUnix(), topic); err != nil {
			lower := strings.ToLower(err.Error())
			if strings.Contains(lower, "unique") || strings.Contains(lower, "constraint") {
				return nil // already friends
			}
			return err
		}
		return nil
	})
	if err != nil {
		return "", err
	}
	// Ensure topic is set even if the row already existed without one.
	return s.ensureFriendshipTopic(req.FromUserID, req.ToUserID)
}

// FriendshipTopic returns the DM topic for two friends.
func (s *Store) FriendshipTopic(userA, userB string) (string, error) {
	return s.ensureFriendshipTopic(userA, userB)
}

func (s *Store) ensureFriendshipTopic(userA, userB string) (string, error) {
	low, high := orderedUserPair(userA, userB)
	var topic sql.NullString
	err := s.db.QueryRow(s.queries.selectFriendshipTopic, low, high).Scan(&topic)
	if err == sql.ErrNoRows {
		return "", ErrNotFound
	} else if err != nil {
		return "", err
	}
	if topic.String != "" {
		return topic.String, nil
	}
	generated := GenerateDMTopic(userA, userB)
	if _, err := s.db.Exec(s.queries.updateFriendshipTopic, generated, low, high); err != nil {
		return "", err
	}
	return generated, nil
}

// RejectFriendRequest marks the request rejected. Only the recipient may reject.
func (s *Store) RejectFriendRequest(requestID, actorUserID string) error {
	req, err := s.FriendRequest(requestID)
	if err != nil {
		return err
	}
	if req.ToUserID != actorUserID {
		return ErrForbidden
	}
	if req.Status != FriendRequestPending {
		return ErrInvalidArgument
	}
	_, err = s.db.Exec(s.queries.updateFriendRequestStatus, FriendRequestRejected, requestID)
	return err
}

// RemoveFriendship deletes the friendship between two users and returns the former DM topic (may be empty).
func (s *Store) RemoveFriendship(userA, userB string) (topic string, err error) {
	low, high := orderedUserPair(userA, userB)
	var t sql.NullString
	_ = s.db.QueryRow(s.queries.selectFriendshipTopic, low, high).Scan(&t)
	topic = t.String
	res, err := s.db.Exec(s.queries.deleteFriendship, low, high)
	if err != nil {
		return topic, err
	}
	n, _ := res.RowsAffected()
	if n == 0 {
		return topic, ErrNotFound
	}
	return topic, nil
}

// Close closes the underlying DB when this store owns it (SQLite). Shared Postgres pools are left open.
func (s *Store) Close() error {
	if s.ownsDB && s.db != nil {
		return s.db.Close()
	}
	return nil
}
