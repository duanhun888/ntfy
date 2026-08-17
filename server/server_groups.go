package server

import (
	"bytes"
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"regexp"
	"strings"

	"heckel.io/ntfy/v2/chatgroup"
	"heckel.io/ntfy/v2/user"
	"heckel.io/ntfy/v2/util"
)

var (
	apiGroupsPath              = "/v1/groups"
	apiGroupsSingleRegex       = regexp.MustCompile(`^/v1/groups/(cg_[-_A-Za-z0-9]+)$`)
	apiGroupsMembersRegex      = regexp.MustCompile(`^/v1/groups/(cg_[-_A-Za-z0-9]+)/members$`)
	apiGroupsMemberSingleRegex = regexp.MustCompile(`^/v1/groups/(cg_[-_A-Za-z0-9]+)/members/([-_.+@a-zA-Z0-9]+)$`)
	apiGroupsBotsRegex         = regexp.MustCompile(`^/v1/groups/(cg_[-_A-Za-z0-9]+)/bots$`)
	apiGroupsBotSingleRegex    = regexp.MustCompile(`^/v1/groups/(cg_[-_A-Za-z0-9]+)/bots/(cb_[-_A-Za-z0-9]+)$`)
	apiHookRegex               = regexp.MustCompile(`^/hook/(wh_[-_A-Za-z0-9]+)$`)
)

type apiGroupCreateRequest struct {
	Name string `json:"name"`
}

type apiGroupMemberAddRequest struct {
	Username string `json:"username"`
}

type apiGroupMemberRoleRequest struct {
	Role string `json:"role"`
}

type apiBotCreateRequest struct {
	Name string `json:"name"`
}

type apiBotCreateResponse struct {
	*chatgroup.Bot
	WebhookURL string `json:"webhook_url"`
}

type dingTalkTextPayload struct {
	MsgType string `json:"msgtype"`
	Text    *struct {
		Content string `json:"content"`
	} `json:"text"`
}

func (s *Server) ensureChatGroups(next handleFunc) handleFunc {
	return func(w http.ResponseWriter, r *http.Request, v *visitor) error {
		if s.chatGroups == nil || s.userManager == nil {
			return errHTTPNotFound
		}
		return next(w, r, v)
	}
}

func (s *Server) handleGroupCreate(w http.ResponseWriter, r *http.Request, v *visitor) error {
	u := v.User()
	req, err := readJSONWithLimit[apiGroupCreateRequest](r.Body, jsonBodyBytesLimit, false)
	if err != nil {
		return err
	}
	name := strings.TrimSpace(req.Name)
	if name == "" {
		return errHTTPBadRequest.Wrap("name required")
	}
	topic := chatgroup.GenerateTopic()
	if !user.AllowedTopic(topic) {
		return errHTTPInternalError
	}
	if err := s.userManager.AllowReservation(u.Name, topic); err != nil {
		return errHTTPConflictTopicReserved
	}
	// Prefer reservation when possible; otherwise grant owner write ACL (self-host without tiers)
	if u.IsAdmin() || u.Tier != nil {
		limit := int64(0)
		if u.Tier != nil {
			limit = u.Tier.ReservationLimit
		}
		if err := s.userManager.AddReservation(u.Name, topic, user.PermissionDenyAll, limit); err != nil {
			if errors.Is(err, user.ErrTooManyReservations) {
				return errHTTPTooManyRequestsLimitReservations
			}
			return err
		}
	} else if err := s.userManager.AllowAccess(u.Name, topic, user.PermissionReadWrite); err != nil {
		return err
	}
	g, err := s.chatGroups.CreateGroup(name, u.ID, topic)
	if err != nil {
		_ = s.userManager.RemoveReservations(u.Name, topic)
		_ = s.userManager.ResetAccess(u.Name, topic)
		return err
	}
	return s.writeJSON(w, g)
}

func (s *Server) handleGroupsList(w http.ResponseWriter, _ *http.Request, v *visitor) error {
	var (
		groups []*chatgroup.Group
		err    error
	)
	if v.User().IsAdmin() {
		groups, err = s.chatGroups.AllGroups()
	} else {
		groups, err = s.chatGroups.GroupsForUser(v.User().ID)
	}
	if err != nil {
		return err
	}
	// Repair older invites that only received read ACL.
	u := v.User()
	for _, g := range groups {
		_ = s.ensureMemberTopicWriteAccess(u.Name, g.Topic)
	}
	return s.writeJSON(w, groups)
}

func (s *Server) handleGroupGet(w http.ResponseWriter, r *http.Request, v *visitor) error {
	id := apiGroupsSingleRegex.FindStringSubmatch(r.URL.Path)[1]
	role, err := s.chatGroups.MemberRole(id, v.User().ID)
	if err != nil {
		if !v.User().IsAdmin() {
			return mapChatErr(err)
		}
		role = ""
	}
	g, err := s.chatGroups.Group(id)
	if err != nil {
		return mapChatErr(err)
	}
	g.Role = role
	return s.writeJSON(w, g)
}

func (s *Server) handleGroupDelete(w http.ResponseWriter, r *http.Request, v *visitor) error {
	id := apiGroupsSingleRegex.FindStringSubmatch(r.URL.Path)[1]
	g, err := s.chatGroups.Group(id)
	if err != nil {
		return mapChatErr(err)
	}
	if g.OwnerUserID != v.User().ID && !v.User().IsAdmin() {
		return errHTTPForbidden
	}
	owner, err := s.userManager.UserByID(g.OwnerUserID)
	if err == nil {
		_ = s.userManager.RemoveReservations(owner.Name, g.Topic)
	}
	if err := s.chatGroups.DeleteGroup(id); err != nil {
		return mapChatErr(err)
	}
	return s.writeJSON(w, newSuccessResponse())
}

func (s *Server) handleGroupMemberAdd(w http.ResponseWriter, r *http.Request, v *visitor) error {
	id := apiGroupsMembersRegex.FindStringSubmatch(r.URL.Path)[1]
	if err := s.requireGroupManage(id, v); err != nil {
		return err
	}
	req, err := readJSONWithLimit[apiGroupMemberAddRequest](r.Body, jsonBodyBytesLimit, false)
	if err != nil {
		return err
	}
	member, err := s.userManager.User(strings.TrimSpace(req.Username))
	if err != nil {
		return errHTTPBadRequestUserNotFound
	}
	g, err := s.chatGroups.Group(id)
	if err != nil {
		return mapChatErr(err)
	}
	if err := s.chatGroups.AddMember(id, member.ID, chatgroup.RoleMember); err != nil {
		return mapChatErr(err)
	}
	// Members need read+write so they can receive and send group chat messages.
	if err := s.userManager.AllowAccess(member.Name, g.Topic, user.PermissionReadWrite); err != nil {
		return err
	}
	return s.writeJSON(w, newSuccessResponse())
}

func (s *Server) handleGroupMembersList(w http.ResponseWriter, r *http.Request, v *visitor) error {
	id := apiGroupsMembersRegex.FindStringSubmatch(r.URL.Path)[1]
	if err := s.requireGroupRead(id, v); err != nil {
		return err
	}
	members, err := s.chatGroups.Members(id)
	if err != nil {
		return err
	}
	for _, m := range members {
		if u, err := s.userManager.UserByID(m.UserID); err == nil {
			m.Username = u.Name
		}
	}
	return s.writeJSON(w, members)
}

func (s *Server) handleGroupMemberRemove(w http.ResponseWriter, r *http.Request, v *visitor) error {
	m := apiGroupsMemberSingleRegex.FindStringSubmatch(r.URL.Path)
	groupID, userKey := m[1], m[2]
	if err := s.requireGroupManage(groupID, v); err != nil {
		return err
	}
	g, err := s.chatGroups.Group(groupID)
	if err != nil {
		return mapChatErr(err)
	}
	member, err := s.userManager.UserByID(userKey)
	if err != nil {
		member, err = s.userManager.User(userKey)
		if err != nil {
			return errHTTPBadRequestUserNotFound
		}
	}
	if member.ID == g.OwnerUserID {
		return errHTTPBadRequest.Wrap("cannot remove owner")
	}
	if err := s.chatGroups.RemoveMember(groupID, member.ID); err != nil {
		return mapChatErr(err)
	}
	_ = s.userManager.ResetAccess(member.Name, g.Topic)
	return s.writeJSON(w, newSuccessResponse())
}

func (s *Server) handleGroupMemberUpdateRole(w http.ResponseWriter, r *http.Request, v *visitor) error {
	m := apiGroupsMemberSingleRegex.FindStringSubmatch(r.URL.Path)
	groupID, userKey := m[1], m[2]
	if err := s.requireGroupManage(groupID, v); err != nil {
		return err
	}
	req, err := readJSONWithLimit[apiGroupMemberRoleRequest](r.Body, jsonBodyBytesLimit, false)
	if err != nil {
		return err
	}
	role := chatgroup.Role(strings.TrimSpace(req.Role))
	member, err := s.userManager.UserByID(userKey)
	if err != nil {
		member, err = s.userManager.User(userKey)
		if err != nil {
			return errHTTPBadRequestUserNotFound
		}
	}
	if err := s.chatGroups.UpdateMemberRole(groupID, member.ID, role); err != nil {
		return mapChatErr(err)
	}
	return s.writeJSON(w, newSuccessResponse())
}

func (s *Server) handleGroupBotCreate(w http.ResponseWriter, r *http.Request, v *visitor) error {
	id := apiGroupsBotsRegex.FindStringSubmatch(r.URL.Path)[1]
	if err := s.requireGroupManage(id, v); err != nil {
		return err
	}
	req, err := readJSONWithLimit[apiBotCreateRequest](r.Body, jsonBodyBytesLimit, false)
	if err != nil {
		return err
	}
	bot, err := s.chatGroups.CreateBot(id, req.Name)
	if err != nil {
		return mapChatErr(err)
	}
	base := strings.TrimRight(s.config.BaseURL, "/")
	if base == "" {
		base = "http://" + r.Host
	}
	return s.writeJSON(w, &apiBotCreateResponse{
		Bot:        bot,
		WebhookURL: base + "/hook/" + bot.Token,
	})
}

func (s *Server) handleGroupBotsList(w http.ResponseWriter, r *http.Request, v *visitor) error {
	id := apiGroupsBotsRegex.FindStringSubmatch(r.URL.Path)[1]
	if err := s.requireGroupRead(id, v); err != nil {
		return err
	}
	bots, err := s.chatGroups.Bots(id)
	if err != nil {
		return err
	}
	return s.writeJSON(w, bots)
}

func (s *Server) handleGroupBotDelete(w http.ResponseWriter, r *http.Request, v *visitor) error {
	m := apiGroupsBotSingleRegex.FindStringSubmatch(r.URL.Path)
	groupID, botID := m[1], m[2]
	if err := s.requireGroupManage(groupID, v); err != nil {
		return err
	}
	bot, err := s.chatGroups.Bot(botID)
	if err != nil {
		return mapChatErr(err)
	}
	if bot.GroupID != groupID {
		return errHTTPNotFound
	}
	if err := s.chatGroups.DeleteBot(botID); err != nil {
		return mapChatErr(err)
	}
	return s.writeJSON(w, newSuccessResponse())
}

// requireGroupRead allows group members or system admins
func (s *Server) requireGroupRead(groupID string, v *visitor) error {
	if _, err := s.chatGroups.MemberRole(groupID, v.User().ID); err != nil {
		if v.User().IsAdmin() {
			return nil
		}
		return mapChatErr(err)
	}
	return nil
}

// requireGroupManage allows group owner/admin members or system admins
func (s *Server) requireGroupManage(groupID string, v *visitor) error {
	if v.User().IsAdmin() {
		return nil
	}
	role, err := s.chatGroups.MemberRole(groupID, v.User().ID)
	if err != nil {
		return mapChatErr(err)
	}
	if role != chatgroup.RoleOwner && role != chatgroup.RoleAdmin {
		return errHTTPForbidden
	}
	return nil
}

// handleHookPublish accepts POSTs from webhook bots (DingTalk-compatible text JSON or plain/ntfy body)
func (s *Server) handleHookPublish(w http.ResponseWriter, r *http.Request, v *visitor) error {
	token := apiHookRegex.FindStringSubmatch(r.URL.Path)[1]
	bwg, err := s.chatGroups.LookupBotToken(token)
	if err != nil {
		return mapChatErr(err)
	}
	owner, err := s.userManager.UserByID(bwg.OwnerUserID)
	if err != nil {
		return errHTTPUnauthorized
	}
	ov := s.visitor(v.IP(), owner)
	t, err := s.topicFromID(ov, bwg.Topic)
	if err != nil {
		return err
	}
	peeked, err := util.Peek(r.Body, s.config.MessageSizeLimit)
	if err != nil {
		return err
	}
	msgBody, title := normalizeHookBody(peeked.PeekedBytes, bwg.Name)
	r.Body = io.NopCloser(bytes.NewReader(msgBody))
	if title != "" {
		r.Header.Set("X-Title", title)
	}
	// Publish as a normal topic message. Leaving /hook/<token> as the request path
	// would match updatePathRegex and reuse the bot token as sequence_id, causing
	// clients to replace earlier messages from this bot.
	r.URL.Path = "/" + bwg.Topic
	r = withContext(r, map[contextKey]any{
		contextTopic:       t,
		contextRateVisitor: ov,
	})
	m, err := s.handlePublishInternal(r, ov)
	if err != nil {
		return err
	}
	return s.writeJSON(w, m.ForJSON())
}

// normalizeHookBody converts DingTalk text JSON or ntfy JSON into a plain message body.
func normalizeHookBody(b []byte, botName string) (body []byte, title string) {
	trimmed := bytes.TrimSpace(b)
	if len(trimmed) == 0 {
		return []byte("triggered"), botName
	}
	if trimmed[0] != '{' {
		return trimmed, botName
	}
	var ding dingTalkTextPayload
	if err := json.Unmarshal(trimmed, &ding); err == nil && strings.EqualFold(ding.MsgType, "text") && ding.Text != nil && ding.Text.Content != "" {
		return []byte(ding.Text.Content), botName
	}
	var ntfyMsg struct {
		Message string `json:"message"`
		Title   string `json:"title"`
	}
	if err := json.Unmarshal(trimmed, &ntfyMsg); err == nil && ntfyMsg.Message != "" {
		t := ntfyMsg.Title
		if t == "" {
			t = botName
		}
		return []byte(ntfyMsg.Message), t
	}
	return trimmed, botName
}

func mapChatErr(err error) error {
	switch {
	case errors.Is(err, chatgroup.ErrNotFound):
		return errHTTPNotFound
	case errors.Is(err, chatgroup.ErrForbidden):
		return errHTTPForbidden
	case errors.Is(err, chatgroup.ErrInvalidArgument):
		return errHTTPBadRequest.Wrap("%s", err.Error())
	case errors.Is(err, chatgroup.ErrAlreadyMember):
		return errHTTPBadRequest.Wrap("already a member")
	default:
		return err
	}
}

// ensureMemberTopicWriteAccess grants read-write on a group topic (idempotent).
func (s *Server) ensureMemberTopicWriteAccess(username, topic string) error {
	if s.userManager == nil || username == "" || topic == "" {
		return nil
	}
	return s.userManager.AllowAccess(username, topic, user.PermissionReadWrite)
}
