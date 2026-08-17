// Package chatgroup provides DingTalk-style groups and webhook bots backed by reserved topics.
package chatgroup

import (
	"errors"
	"time"
)

const (
	groupIDPrefix = "cg_"
	groupIDLength = 12
	botIDPrefix   = "cb_"
	botIDLength   = 12
	tokenPrefix   = "wh_"
	tokenLength   = 32 // includes prefix
	topicPrefix   = "g_"
	topicLength   = 16 // includes prefix; must match AllowedTopic

	routeIDPrefix    = "ar_"
	routeIDLength    = 12
	routeTokenPrefix = "at_"
	routeTokenLength = 32 // includes prefix

	deliveryIDPrefix = "ad_"
	deliveryIDLength = 12
	deliveryMsgMax   = 500

	friendRequestIDPrefix = "fr_"
	friendRequestIDLength = 12

	dmTopicPrefix = "d_"
	dmTopicLength = 16 // includes prefix; matches AllowedTopic

	schemaStore = "chatgroup"
)

// Errors
var (
	ErrNotFound         = errors.New("not found")
	ErrForbidden        = errors.New("forbidden")
	ErrInvalidArgument  = errors.New("invalid argument")
	ErrAlreadyMember    = errors.New("already a member")
	ErrAlreadyFriends   = errors.New("already friends")
	ErrAlreadyRequested = errors.New("friend request already pending")
)

// FriendRequestStatus values
const (
	FriendRequestPending  = "pending"
	FriendRequestAccepted = "accepted"
	FriendRequestRejected = "rejected"
)

// Friend is a mutual friendship entry from the caller's perspective.
type Friend struct {
	UserID   string `json:"user_id"`
	Username string `json:"username,omitempty"`
    Topic    string `json:"topic"` // private DM topic shared by both users
	Created  int64  `json:"created"`
}

// FriendRequest is a pending/accepted/rejected friend request.
type FriendRequest struct {
	ID           string `json:"id"`
	FromUserID   string `json:"from_user_id"`
	FromUsername string `json:"from_username,omitempty"`
	ToUserID     string `json:"to_user_id"`
	ToUsername   string `json:"to_username,omitempty"`
	Status       string `json:"status"`
	Created      int64  `json:"created"`
}

// Role of a group member
type Role string

// Member roles
const (
	RoleOwner  Role = "owner"
	RoleAdmin  Role = "admin"
	RoleMember Role = "member"
)

// Group is a chat group backed by an internal reserved topic
type Group struct {
	ID          string `json:"id"`
	Name        string `json:"name"`
	OwnerUserID string `json:"owner_user_id"`
	Topic       string `json:"topic"`
	Created     int64  `json:"created"`
	MemberCount int64  `json:"member_count,omitempty"`
	Role        Role   `json:"role,omitempty"` // caller's role when listed
}

// Member is a group member
type Member struct {
	UserID   string `json:"user_id"`
	Username string `json:"username,omitempty"`
	Role     Role   `json:"role"`
	Joined   int64  `json:"joined"`
}

// Bot is a webhook bot belonging to a group
type Bot struct {
	ID        string `json:"id"`
	GroupID   string `json:"group_id"`
	Name      string `json:"name"`
	Token     string `json:"token,omitempty"`      // full token only on create
	TokenHint string `json:"token_hint,omitempty"` // last 4 chars for list
	Created   int64  `json:"created"`
}

// BotWithGroup is returned by webhook lookup
type BotWithGroup struct {
	Bot
	Topic       string
	OwnerUserID string
}

// AlertRoute maps a business type to an app group and/or WeCom webhook.
type AlertRoute struct {
	ID           string `json:"id"`
	BizType      string `json:"biz_type"`
	Name         string `json:"name"`
	Token        string `json:"token,omitempty"`      // full token only on create
	TokenHint    string `json:"token_hint,omitempty"` // last 4 chars for list
	GroupID      string `json:"group_id,omitempty"`
	WeComWebhook string `json:"wecom_webhook,omitempty"`
	Enabled      bool   `json:"enabled"`
	OwnerUserID  string `json:"owner_user_id"`
	Created      int64  `json:"created"`
}

// AlertDelivery is one trigger attempt for an alert route.
type AlertDelivery struct {
	ID          string `json:"id"`
	RouteID     string `json:"route_id"`
	BizType     string `json:"biz_type"`
	OwnerUserID string `json:"owner_user_id"`
	Message     string `json:"message"`
	AppOK       *bool  `json:"app_ok,omitempty"`
	WeComOK     *bool  `json:"wecom_ok,omitempty"`
	WeComError  string `json:"wecom_error,omitempty"`
	Created     int64  `json:"created"`
}

// DeliveryStats aggregates deliveries since a unix timestamp.
type DeliveryStats struct {
	Total  int64 `json:"total"`
	Failed int64 `json:"failed"`
}

// NowUnix helper
func NowUnix() int64 {
	return time.Now().Unix()
}
