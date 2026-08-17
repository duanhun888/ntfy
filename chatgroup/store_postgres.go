package chatgroup

import (
	"database/sql"
	"fmt"
	"strings"

	"heckel.io/ntfy/v2/db"
	"heckel.io/ntfy/v2/db/schema"
)

const (
	postgresCurrentSchemaVersion = 5

	postgresCreateTables = `
		CREATE TABLE IF NOT EXISTS chat_group (
			id TEXT PRIMARY KEY,
			name TEXT NOT NULL,
			owner_user_id TEXT NOT NULL,
			topic TEXT NOT NULL UNIQUE,
			created BIGINT NOT NULL
		);
		CREATE TABLE IF NOT EXISTS chat_group_member (
			group_id TEXT NOT NULL,
			user_id TEXT NOT NULL,
			role TEXT NOT NULL,
			joined BIGINT NOT NULL,
			PRIMARY KEY (group_id, user_id),
			FOREIGN KEY (group_id) REFERENCES chat_group (id) ON DELETE CASCADE
		);
		CREATE INDEX IF NOT EXISTS idx_chat_group_member_user ON chat_group_member (user_id);
		CREATE TABLE IF NOT EXISTS chat_bot (
			id TEXT PRIMARY KEY,
			group_id TEXT NOT NULL,
			name TEXT NOT NULL,
			token TEXT NOT NULL UNIQUE,
			created BIGINT NOT NULL,
			FOREIGN KEY (group_id) REFERENCES chat_group (id) ON DELETE CASCADE
		);
		CREATE INDEX IF NOT EXISTS idx_chat_bot_group ON chat_bot (group_id);
		CREATE TABLE IF NOT EXISTS alert_route (
			id TEXT PRIMARY KEY,
			biz_type TEXT NOT NULL UNIQUE,
			name TEXT NOT NULL,
			token TEXT NOT NULL UNIQUE,
			group_id TEXT,
			wecom_webhook TEXT,
			enabled INT NOT NULL DEFAULT 1,
			owner_user_id TEXT NOT NULL,
			created BIGINT NOT NULL,
			FOREIGN KEY (group_id) REFERENCES chat_group (id) ON DELETE SET NULL
		);
		CREATE INDEX IF NOT EXISTS idx_alert_route_owner ON alert_route (owner_user_id);
		CREATE TABLE IF NOT EXISTS alert_delivery (
			id TEXT PRIMARY KEY,
			route_id TEXT NOT NULL,
			biz_type TEXT NOT NULL,
			owner_user_id TEXT NOT NULL,
			message TEXT NOT NULL DEFAULT '',
			app_ok INT,
			wecom_ok INT,
			wecom_error TEXT,
			created BIGINT NOT NULL
		);
		CREATE INDEX IF NOT EXISTS idx_alert_delivery_owner_created ON alert_delivery (owner_user_id, created DESC);
		CREATE INDEX IF NOT EXISTS idx_alert_delivery_created ON alert_delivery (created DESC);
		CREATE INDEX IF NOT EXISTS idx_alert_delivery_biz ON alert_delivery (biz_type, created DESC);
		CREATE TABLE IF NOT EXISTS friend_request (
			id TEXT PRIMARY KEY,
			from_user_id TEXT NOT NULL,
			to_user_id TEXT NOT NULL,
			status TEXT NOT NULL,
			created BIGINT NOT NULL
		);
		CREATE INDEX IF NOT EXISTS idx_friend_request_to_status ON friend_request (to_user_id, status);
		CREATE INDEX IF NOT EXISTS idx_friend_request_from_status ON friend_request (from_user_id, status);
		CREATE TABLE IF NOT EXISTS friendship (
			user_low TEXT NOT NULL,
			user_high TEXT NOT NULL,
			created BIGINT NOT NULL,
			topic TEXT NOT NULL DEFAULT '',
			PRIMARY KEY (user_low, user_high)
		);
	`

	postgresMigrateV1ToV2 = `
		CREATE TABLE IF NOT EXISTS alert_route (
			id TEXT PRIMARY KEY,
			biz_type TEXT NOT NULL UNIQUE,
			name TEXT NOT NULL,
			token TEXT NOT NULL UNIQUE,
			group_id TEXT,
			wecom_webhook TEXT,
			enabled INT NOT NULL DEFAULT 1,
			owner_user_id TEXT NOT NULL,
			created BIGINT NOT NULL,
			FOREIGN KEY (group_id) REFERENCES chat_group (id) ON DELETE SET NULL
		);
		CREATE INDEX IF NOT EXISTS idx_alert_route_owner ON alert_route (owner_user_id);
	`

	postgresMigrateV2ToV3 = `
		CREATE TABLE IF NOT EXISTS alert_delivery (
			id TEXT PRIMARY KEY,
			route_id TEXT NOT NULL,
			biz_type TEXT NOT NULL,
			owner_user_id TEXT NOT NULL,
			message TEXT NOT NULL DEFAULT '',
			app_ok INT,
			wecom_ok INT,
			wecom_error TEXT,
			created BIGINT NOT NULL
		);
		CREATE INDEX IF NOT EXISTS idx_alert_delivery_owner_created ON alert_delivery (owner_user_id, created DESC);
		CREATE INDEX IF NOT EXISTS idx_alert_delivery_created ON alert_delivery (created DESC);
		CREATE INDEX IF NOT EXISTS idx_alert_delivery_biz ON alert_delivery (biz_type, created DESC);
	`

	postgresMigrateV3ToV4 = `
		CREATE TABLE IF NOT EXISTS friend_request (
			id TEXT PRIMARY KEY,
			from_user_id TEXT NOT NULL,
			to_user_id TEXT NOT NULL,
			status TEXT NOT NULL,
			created BIGINT NOT NULL
		);
		CREATE INDEX IF NOT EXISTS idx_friend_request_to_status ON friend_request (to_user_id, status);
		CREATE INDEX IF NOT EXISTS idx_friend_request_from_status ON friend_request (from_user_id, status);
		CREATE TABLE IF NOT EXISTS friendship (
			user_low TEXT NOT NULL,
			user_high TEXT NOT NULL,
			created BIGINT NOT NULL,
			PRIMARY KEY (user_low, user_high)
		);
	`

	postgresMigrateV4ToV5 = `
		ALTER TABLE friendship ADD COLUMN IF NOT EXISTS topic TEXT NOT NULL DEFAULT '';
	`
)

// NewPostgresStore uses the shared Postgres pool
func NewPostgresStore(pool *db.DB) (*Store, error) {
	migrations := map[int]schema.MigrateFunc{
		1: func(tx *sql.Tx) error {
			_, err := tx.Exec(postgresMigrateV1ToV2)
			return err
		},
		2: func(tx *sql.Tx) error {
			_, err := tx.Exec(postgresMigrateV2ToV3)
			return err
		},
		3: func(tx *sql.Tx) error {
			_, err := tx.Exec(postgresMigrateV3ToV4)
			return err
		},
		4: func(tx *sql.Tx) error {
			_, err := tx.Exec(postgresMigrateV4ToV5)
			return err
		},
	}
	if err := schema.Migrate(pool.Primary(), schema.Postgres, schemaStore, postgresCurrentSchemaVersion, func(tx *sql.Tx) error {
		_, err := tx.Exec(postgresCreateTables)
		return err
	}, migrations); err != nil {
		return nil, fmt.Errorf("chatgroup schema: %w", err)
	}
	return &Store{db: pool, queries: postgresQueries(), ownsDB: false}, nil
}

func postgresQueries() queries {
	q := sqliteQueries()
	// Convert ? placeholders to $1, $2, ... for pgx
	convert := func(s string) string {
		var b strings.Builder
		n := 1
		for i := 0; i < len(s); i++ {
			if s[i] == '?' {
				b.WriteByte('$')
				b.WriteString(fmt.Sprintf("%d", n))
				n++
			} else {
				b.WriteByte(s[i])
			}
		}
		return b.String()
	}
	return queries{
		insertGroup:                  convert(q.insertGroup),
		selectGroupByID:              convert(q.selectGroupByID),
		selectGroupsForUser:          convert(q.selectGroupsForUser),
		selectAllGroups:              convert(q.selectAllGroups),
		deleteGroup:                  convert(q.deleteGroup),
		insertMember:                 convert(q.insertMember),
		selectMember:                 convert(q.selectMember),
		selectMembers:                convert(q.selectMembers),
		deleteMember:                 convert(q.deleteMember),
		deleteMembersByGroup:         convert(q.deleteMembersByGroup),
		countMembers:                 convert(q.countMembers),
		updateMemberRole:             convert(q.updateMemberRole),
		insertBot:                    convert(q.insertBot),
		selectBotByID:                convert(q.selectBotByID),
		selectBotByToken:             convert(q.selectBotByToken),
		selectBotsByGroup:            convert(q.selectBotsByGroup),
		deleteBot:                    convert(q.deleteBot),
		deleteBotsByGroup:            convert(q.deleteBotsByGroup),
		insertRoute:                  convert(q.insertRoute),
		selectRouteByID:              convert(q.selectRouteByID),
		selectRouteByBizType:         convert(q.selectRouteByBizType),
		selectRoutesForUser:          convert(q.selectRoutesForUser),
		selectAllRoutes:              convert(q.selectAllRoutes),
		updateRoute:                  convert(q.updateRoute),
		deleteRoute:                  convert(q.deleteRoute),
		insertDelivery:               convert(q.insertDelivery),
		selectDeliveriesForUser:      convert(q.selectDeliveriesForUser),
		selectAllDeliveries:          convert(q.selectAllDeliveries),
		selectDeliveryStats:          convert(q.selectDeliveryStats),
		selectDeliveryStatsUser:      convert(q.selectDeliveryStatsUser),
		insertFriendRequest:          convert(q.insertFriendRequest),
		selectFriendRequestByID:      convert(q.selectFriendRequestByID),
		selectPendingRequest:         convert(q.selectPendingRequest),
		selectIncomingFriendRequests: convert(q.selectIncomingFriendRequests),
		selectOutgoingFriendRequests: convert(q.selectOutgoingFriendRequests),
		updateFriendRequestStatus:    convert(q.updateFriendRequestStatus),
		insertFriendship:             convert(q.insertFriendship),
		selectFriendship:             convert(q.selectFriendship),
		selectFriendsForUser:         convert(q.selectFriendsForUser),
		selectFriendshipTopic:        convert(q.selectFriendshipTopic),
		updateFriendshipTopic:        convert(q.updateFriendshipTopic),
		deleteFriendship:             convert(q.deleteFriendship),
	}
}
