package chatgroup

import (
	"database/sql"
	"fmt"

	_ "github.com/mattn/go-sqlite3"

	"heckel.io/ntfy/v2/db"
	"heckel.io/ntfy/v2/db/schema"
)

const (
	sqliteCurrentSchemaVersion = 5

	sqliteCreateTables = `
		CREATE TABLE IF NOT EXISTS chat_group (
			id TEXT PRIMARY KEY,
			name TEXT NOT NULL,
			owner_user_id TEXT NOT NULL,
			topic TEXT NOT NULL UNIQUE,
			created INT NOT NULL
		);
		CREATE TABLE IF NOT EXISTS chat_group_member (
			group_id TEXT NOT NULL,
			user_id TEXT NOT NULL,
			role TEXT NOT NULL,
			joined INT NOT NULL,
			PRIMARY KEY (group_id, user_id),
			FOREIGN KEY (group_id) REFERENCES chat_group (id) ON DELETE CASCADE
		);
		CREATE INDEX IF NOT EXISTS idx_chat_group_member_user ON chat_group_member (user_id);
		CREATE TABLE IF NOT EXISTS chat_bot (
			id TEXT PRIMARY KEY,
			group_id TEXT NOT NULL,
			name TEXT NOT NULL,
			token TEXT NOT NULL UNIQUE,
			created INT NOT NULL,
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
			created INT NOT NULL,
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
			created INT NOT NULL
		);
		CREATE INDEX IF NOT EXISTS idx_alert_delivery_owner_created ON alert_delivery (owner_user_id, created DESC);
		CREATE INDEX IF NOT EXISTS idx_alert_delivery_created ON alert_delivery (created DESC);
		CREATE INDEX IF NOT EXISTS idx_alert_delivery_biz ON alert_delivery (biz_type, created DESC);
		CREATE TABLE IF NOT EXISTS friend_request (
			id TEXT PRIMARY KEY,
			from_user_id TEXT NOT NULL,
			to_user_id TEXT NOT NULL,
			status TEXT NOT NULL,
			created INT NOT NULL
		);
		CREATE INDEX IF NOT EXISTS idx_friend_request_to_status ON friend_request (to_user_id, status);
		CREATE INDEX IF NOT EXISTS idx_friend_request_from_status ON friend_request (from_user_id, status);
		CREATE TABLE IF NOT EXISTS friendship (
			user_low TEXT NOT NULL,
			user_high TEXT NOT NULL,
			created INT NOT NULL,
			topic TEXT NOT NULL DEFAULT '',
			PRIMARY KEY (user_low, user_high)
		);
	`

	sqliteMigrateV1ToV2 = `
		CREATE TABLE IF NOT EXISTS alert_route (
			id TEXT PRIMARY KEY,
			biz_type TEXT NOT NULL UNIQUE,
			name TEXT NOT NULL,
			token TEXT NOT NULL UNIQUE,
			group_id TEXT,
			wecom_webhook TEXT,
			enabled INT NOT NULL DEFAULT 1,
			owner_user_id TEXT NOT NULL,
			created INT NOT NULL,
			FOREIGN KEY (group_id) REFERENCES chat_group (id) ON DELETE SET NULL
		);
		CREATE INDEX IF NOT EXISTS idx_alert_route_owner ON alert_route (owner_user_id);
	`

	sqliteMigrateV2ToV3 = `
		CREATE TABLE IF NOT EXISTS alert_delivery (
			id TEXT PRIMARY KEY,
			route_id TEXT NOT NULL,
			biz_type TEXT NOT NULL,
			owner_user_id TEXT NOT NULL,
			message TEXT NOT NULL DEFAULT '',
			app_ok INT,
			wecom_ok INT,
			wecom_error TEXT,
			created INT NOT NULL
		);
		CREATE INDEX IF NOT EXISTS idx_alert_delivery_owner_created ON alert_delivery (owner_user_id, created DESC);
		CREATE INDEX IF NOT EXISTS idx_alert_delivery_created ON alert_delivery (created DESC);
		CREATE INDEX IF NOT EXISTS idx_alert_delivery_biz ON alert_delivery (biz_type, created DESC);
	`

	sqliteMigrateV3ToV4 = `
		CREATE TABLE IF NOT EXISTS friend_request (
			id TEXT PRIMARY KEY,
			from_user_id TEXT NOT NULL,
			to_user_id TEXT NOT NULL,
			status TEXT NOT NULL,
			created INT NOT NULL
		);
		CREATE INDEX IF NOT EXISTS idx_friend_request_to_status ON friend_request (to_user_id, status);
		CREATE INDEX IF NOT EXISTS idx_friend_request_from_status ON friend_request (from_user_id, status);
		CREATE TABLE IF NOT EXISTS friendship (
			user_low TEXT NOT NULL,
			user_high TEXT NOT NULL,
			created INT NOT NULL,
			PRIMARY KEY (user_low, user_high)
		);
	`

	sqliteMigrateV4ToV5 = `
		ALTER TABLE friendship ADD COLUMN topic TEXT NOT NULL DEFAULT '';
	`

	sqliteInsertGroup         = `INSERT INTO chat_group (id, name, owner_user_id, topic, created) VALUES (?, ?, ?, ?, ?)`
	sqliteSelectGroupByID     = `SELECT id, name, owner_user_id, topic, created FROM chat_group WHERE id = ?`
	sqliteSelectGroupsForUser = `
		SELECT g.id, g.name, g.owner_user_id, g.topic, g.created, m.role,
			(SELECT COUNT(*) FROM chat_group_member cm WHERE cm.group_id = g.id)
		FROM chat_group g
		JOIN chat_group_member m ON m.group_id = g.id
		WHERE m.user_id = ?
		ORDER BY g.created DESC
	`
	sqliteSelectAllGroups = `
		SELECT g.id, g.name, g.owner_user_id, g.topic, g.created,
			(SELECT COUNT(*) FROM chat_group_member cm WHERE cm.group_id = g.id)
		FROM chat_group g
		ORDER BY g.created DESC
	`
	sqliteDeleteGroup          = `DELETE FROM chat_group WHERE id = ?`
	sqliteInsertMember         = `INSERT INTO chat_group_member (group_id, user_id, role, joined) VALUES (?, ?, ?, ?)`
	sqliteSelectMember         = `SELECT role FROM chat_group_member WHERE group_id = ? AND user_id = ?`
	sqliteSelectMembers        = `SELECT user_id, role, joined FROM chat_group_member WHERE group_id = ? ORDER BY joined`
	sqliteDeleteMember         = `DELETE FROM chat_group_member WHERE group_id = ? AND user_id = ?`
	sqliteDeleteMembersByGroup = `DELETE FROM chat_group_member WHERE group_id = ?`
	sqliteCountMembers         = `SELECT COUNT(*) FROM chat_group_member WHERE group_id = ?`
	sqliteUpdateMemberRole     = `UPDATE chat_group_member SET role = ? WHERE group_id = ? AND user_id = ? AND role != 'owner'`
	sqliteInsertBot            = `INSERT INTO chat_bot (id, group_id, name, token, created) VALUES (?, ?, ?, ?, ?)`
	sqliteSelectBotByID        = `SELECT id, group_id, name, token, created FROM chat_bot WHERE id = ?`
	sqliteSelectBotByToken     = `
		SELECT b.id, b.group_id, b.name, b.token, b.created, g.topic, g.owner_user_id
		FROM chat_bot b
		JOIN chat_group g ON g.id = b.group_id
		WHERE b.token = ?
	`
	sqliteSelectBotsByGroup = `SELECT id, group_id, name, token, created FROM chat_bot WHERE group_id = ? ORDER BY created`
	sqliteDeleteBot         = `DELETE FROM chat_bot WHERE id = ?`
	sqliteDeleteBotsByGroup = `DELETE FROM chat_bot WHERE group_id = ?`

	sqliteInsertRoute = `
		INSERT INTO alert_route (id, biz_type, name, token, group_id, wecom_webhook, enabled, owner_user_id, created)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
	`
	sqliteSelectRouteByID = `
		SELECT id, biz_type, name, token, group_id, wecom_webhook, enabled, owner_user_id, created
		FROM alert_route WHERE id = ?
	`
	sqliteSelectRouteByBizType = `
		SELECT id, biz_type, name, token, group_id, wecom_webhook, enabled, owner_user_id, created
		FROM alert_route WHERE biz_type = ?
	`
	sqliteSelectRoutesForUser = `
		SELECT id, biz_type, name, token, group_id, wecom_webhook, enabled, owner_user_id, created
		FROM alert_route WHERE owner_user_id = ?
		ORDER BY created DESC
	`
	sqliteSelectAllRoutes = `
		SELECT id, biz_type, name, token, group_id, wecom_webhook, enabled, owner_user_id, created
		FROM alert_route
		ORDER BY created DESC
	`
	sqliteUpdateRoute = `
		UPDATE alert_route SET name = ?, group_id = ?, wecom_webhook = ?, enabled = ?
		WHERE id = ?
	`
	sqliteDeleteRoute = `DELETE FROM alert_route WHERE id = ?`

	sqliteInsertDelivery = `
		INSERT INTO alert_delivery (id, route_id, biz_type, owner_user_id, message, app_ok, wecom_ok, wecom_error, created)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
	`
	sqliteSelectDeliveriesForUser = `
		SELECT id, route_id, biz_type, owner_user_id, message, app_ok, wecom_ok, wecom_error, created
		FROM alert_delivery
		WHERE owner_user_id = ?
		  AND (? = '' OR biz_type = ?)
		ORDER BY created DESC
		LIMIT ?
	`
	sqliteSelectAllDeliveries = `
		SELECT id, route_id, biz_type, owner_user_id, message, app_ok, wecom_ok, wecom_error, created
		FROM alert_delivery
		WHERE (? = '' OR biz_type = ?)
		ORDER BY created DESC
		LIMIT ?
	`
	sqliteSelectDeliveryStats = `
		SELECT
			COUNT(*),
			COALESCE(SUM(CASE
				WHEN (app_ok IS NOT NULL AND app_ok = 0) OR (wecom_ok IS NOT NULL AND wecom_ok = 0) THEN 1
				ELSE 0
			END), 0)
		FROM alert_delivery
		WHERE created >= ?
	`
	sqliteSelectDeliveryStatsUser = `
		SELECT
			COUNT(*),
			COALESCE(SUM(CASE
				WHEN (app_ok IS NOT NULL AND app_ok = 0) OR (wecom_ok IS NOT NULL AND wecom_ok = 0) THEN 1
				ELSE 0
			END), 0)
		FROM alert_delivery
		WHERE created >= ? AND owner_user_id = ?
	`

	sqliteInsertFriendRequest = `
		INSERT INTO friend_request (id, from_user_id, to_user_id, status, created)
		VALUES (?, ?, ?, ?, ?)
	`
	sqliteSelectFriendRequestByID = `
		SELECT id, from_user_id, to_user_id, status, created FROM friend_request WHERE id = ?
	`
	sqliteSelectPendingRequest = `
		SELECT id FROM friend_request
		WHERE from_user_id = ? AND to_user_id = ? AND status = 'pending'
		LIMIT 1
	`
	sqliteSelectIncomingFriendRequests = `
		SELECT id, from_user_id, to_user_id, status, created FROM friend_request
		WHERE to_user_id = ? AND (? = '' OR status = ?)
		ORDER BY created DESC
	`
	sqliteSelectOutgoingFriendRequests = `
		SELECT id, from_user_id, to_user_id, status, created FROM friend_request
		WHERE from_user_id = ? AND (? = '' OR status = ?)
		ORDER BY created DESC
	`
	sqliteUpdateFriendRequestStatus = `UPDATE friend_request SET status = ? WHERE id = ?`
	sqliteInsertFriendship          = `INSERT INTO friendship (user_low, user_high, created, topic) VALUES (?, ?, ?, ?)`
	sqliteSelectFriendship          = `SELECT 1 FROM friendship WHERE user_low = ? AND user_high = ?`
	sqliteSelectFriendsForUser      = `
		SELECT CASE WHEN user_low = ? THEN user_high ELSE user_low END AS friend_id, created, topic
		FROM friendship
		WHERE user_low = ? OR user_high = ?
		ORDER BY created DESC
	`
	sqliteSelectFriendshipTopic = `SELECT topic FROM friendship WHERE user_low = ? AND user_high = ?`
	sqliteUpdateFriendshipTopic = `UPDATE friendship SET topic = ? WHERE user_low = ? AND user_high = ?`
	sqliteDeleteFriendship      = `DELETE FROM friendship WHERE user_low = ? AND user_high = ?`
)

// NewSQLiteStore opens or creates a SQLite-backed chatgroup store
func NewSQLiteStore(filename string) (*Store, error) {
	d, err := sql.Open("sqlite3", filename)
	if err != nil {
		return nil, err
	}
	if _, err := d.Exec(`PRAGMA foreign_keys = ON`); err != nil {
		_ = d.Close()
		return nil, err
	}
	migrations := map[int]schema.MigrateFunc{
		1: func(tx *sql.Tx) error {
			_, err := tx.Exec(sqliteMigrateV1ToV2)
			return err
		},
		2: func(tx *sql.Tx) error {
			_, err := tx.Exec(sqliteMigrateV2ToV3)
			return err
		},
		3: func(tx *sql.Tx) error {
			_, err := tx.Exec(sqliteMigrateV3ToV4)
			return err
		},
		4: func(tx *sql.Tx) error {
			_, err := tx.Exec(sqliteMigrateV4ToV5)
			return err
		},
	}
	if err := schema.Migrate(d, schema.SQLite, schemaStore, sqliteCurrentSchemaVersion, func(tx *sql.Tx) error {
		_, err := tx.Exec(sqliteCreateTables)
		return err
	}, migrations); err != nil {
		_ = d.Close()
		return nil, fmt.Errorf("chatgroup schema: %w", err)
	}
	return &Store{db: db.New(&db.Host{DB: d}, nil), queries: sqliteQueries(), ownsDB: true}, nil
}

func sqliteQueries() queries {
	return queries{
		insertGroup:                  sqliteInsertGroup,
		selectGroupByID:              sqliteSelectGroupByID,
		selectGroupsForUser:          sqliteSelectGroupsForUser,
		selectAllGroups:              sqliteSelectAllGroups,
		deleteGroup:                  sqliteDeleteGroup,
		insertMember:                 sqliteInsertMember,
		selectMember:                 sqliteSelectMember,
		selectMembers:                sqliteSelectMembers,
		deleteMember:                 sqliteDeleteMember,
		deleteMembersByGroup:         sqliteDeleteMembersByGroup,
		countMembers:                 sqliteCountMembers,
		updateMemberRole:             sqliteUpdateMemberRole,
		insertBot:                    sqliteInsertBot,
		selectBotByID:                sqliteSelectBotByID,
		selectBotByToken:             sqliteSelectBotByToken,
		selectBotsByGroup:            sqliteSelectBotsByGroup,
		deleteBot:                    sqliteDeleteBot,
		deleteBotsByGroup:            sqliteDeleteBotsByGroup,
		insertRoute:                  sqliteInsertRoute,
		selectRouteByID:              sqliteSelectRouteByID,
		selectRouteByBizType:         sqliteSelectRouteByBizType,
		selectRoutesForUser:          sqliteSelectRoutesForUser,
		selectAllRoutes:              sqliteSelectAllRoutes,
		updateRoute:                  sqliteUpdateRoute,
		deleteRoute:                  sqliteDeleteRoute,
		insertDelivery:               sqliteInsertDelivery,
		selectDeliveriesForUser:      sqliteSelectDeliveriesForUser,
		selectAllDeliveries:          sqliteSelectAllDeliveries,
		selectDeliveryStats:          sqliteSelectDeliveryStats,
		selectDeliveryStatsUser:      sqliteSelectDeliveryStatsUser,
		insertFriendRequest:          sqliteInsertFriendRequest,
		selectFriendRequestByID:      sqliteSelectFriendRequestByID,
		selectPendingRequest:         sqliteSelectPendingRequest,
		selectIncomingFriendRequests: sqliteSelectIncomingFriendRequests,
		selectOutgoingFriendRequests: sqliteSelectOutgoingFriendRequests,
		updateFriendRequestStatus:    sqliteUpdateFriendRequestStatus,
		insertFriendship:             sqliteInsertFriendship,
		selectFriendship:             sqliteSelectFriendship,
		selectFriendsForUser:         sqliteSelectFriendsForUser,
		selectFriendshipTopic:        sqliteSelectFriendshipTopic,
		updateFriendshipTopic:        sqliteUpdateFriendshipTopic,
		deleteFriendship:             sqliteDeleteFriendship,
	}
}
