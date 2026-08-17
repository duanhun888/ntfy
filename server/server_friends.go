package server

import (
	"errors"
	"net/http"
	"regexp"
	"strings"

	"heckel.io/ntfy/v2/chatgroup"
	"heckel.io/ntfy/v2/user"
)

var (
	apiFriendsPath               = "/v1/friends"
	apiFriendsRequestsPath       = "/v1/friends/requests"
	apiFriendsRequestActionRegex = regexp.MustCompile(`^/v1/friends/requests/(fr_[-_A-Za-z0-9]+)/(accept|reject)$`)
	apiFriendsSingleRegex        = regexp.MustCompile(`^/v1/friends/([-_.+@a-zA-Z0-9]+)$`)
)

type apiFriendRequestCreate struct {
	Username string `json:"username"`
}

func (s *Server) handleFriendsList(w http.ResponseWriter, _ *http.Request, v *visitor) error {
	u := v.User()
	friends, err := s.chatGroups.ListFriends(u.ID)
	if err != nil {
		return err
	}
	for _, f := range friends {
		if other, err := s.userManager.UserByID(f.UserID); err == nil {
			f.Username = other.Name
			_ = s.ensureFriendDMAccess(u.Name, other.Name, f.Topic)
		}
	}
	return s.writeJSON(w, friends)
}

func (s *Server) handleFriendRequestCreate(w http.ResponseWriter, r *http.Request, v *visitor) error {
	u := v.User()
	req, err := readJSONWithLimit[apiFriendRequestCreate](r.Body, jsonBodyBytesLimit, false)
	if err != nil {
		return err
	}
	username := strings.TrimSpace(req.Username)
	if username == "" {
		return errHTTPBadRequest.Wrap("username required")
	}
	target, err := s.userManager.User(username)
	if err != nil {
		return errHTTPBadRequestUserNotFound
	}
	if target.ID == u.ID {
		return errHTTPBadRequest.Wrap("cannot add yourself")
	}
	fr, err := s.chatGroups.CreateFriendRequest(u.ID, target.ID)
	if err != nil {
		return mapFriendErr(err)
	}
	fr.FromUsername = u.Name
	fr.ToUsername = target.Name
	return s.writeJSON(w, fr)
}

func (s *Server) handleFriendRequestsList(w http.ResponseWriter, r *http.Request, v *visitor) error {
	u := v.User()
	box := r.URL.Query().Get("box")
	if box == "" {
		box = "incoming"
	}
	status := r.URL.Query().Get("status")
	if status == "" && box == "incoming" {
		status = chatgroup.FriendRequestPending
	}
	list, err := s.chatGroups.ListFriendRequests(u.ID, box, status)
	if err != nil {
		return mapFriendErr(err)
	}
	for _, fr := range list {
		if from, err := s.userManager.UserByID(fr.FromUserID); err == nil {
			fr.FromUsername = from.Name
		}
		if to, err := s.userManager.UserByID(fr.ToUserID); err == nil {
			fr.ToUsername = to.Name
		}
	}
	return s.writeJSON(w, list)
}

func (s *Server) handleFriendRequestAction(w http.ResponseWriter, r *http.Request, v *visitor) error {
	m := apiFriendsRequestActionRegex.FindStringSubmatch(r.URL.Path)
	requestID, action := m[1], m[2]
	u := v.User()
	switch action {
	case "accept":
		req, err := s.chatGroups.FriendRequest(requestID)
		if err != nil {
			return mapFriendErr(err)
		}
		topic, err := s.chatGroups.AcceptFriendRequest(requestID, u.ID)
		if err != nil {
			return mapFriendErr(err)
		}
		fromUser, errFrom := s.userManager.UserByID(req.FromUserID)
		toUser, errTo := s.userManager.UserByID(req.ToUserID)
		if errFrom == nil && errTo == nil {
			_ = s.ensureFriendDMAccess(fromUser.Name, toUser.Name, topic)
		}
		return s.writeJSON(w, map[string]any{
			"success": true,
			"topic":   topic,
		})
	case "reject":
		if err := s.chatGroups.RejectFriendRequest(requestID, u.ID); err != nil {
			return mapFriendErr(err)
		}
		return s.writeJSON(w, newSuccessResponse())
	default:
		return errHTTPBadRequest
	}
}

func (s *Server) handleFriendDelete(w http.ResponseWriter, r *http.Request, v *visitor) error {
	userKey := apiFriendsSingleRegex.FindStringSubmatch(r.URL.Path)[1]
	u := v.User()
	other, err := s.userManager.UserByID(userKey)
	if err != nil {
		other, err = s.userManager.User(userKey)
		if err != nil {
			return errHTTPBadRequestUserNotFound
		}
	}
	topic, err := s.chatGroups.RemoveFriendship(u.ID, other.ID)
	if err != nil {
		return mapFriendErr(err)
	}
	if topic != "" {
		_ = s.userManager.ResetAccess(u.Name, topic)
		_ = s.userManager.ResetAccess(other.Name, topic)
	}
	return s.writeJSON(w, newSuccessResponse())
}

// ensureFriendDMAccess grants both users read-write on the private DM topic.
func (s *Server) ensureFriendDMAccess(userA, userB, topic string) error {
	if s.userManager == nil || topic == "" || userA == "" || userB == "" {
		return nil
	}
	if !user.AllowedTopic(topic) {
		return errHTTPInternalError
	}
	if err := s.userManager.AllowAccess(userA, topic, user.PermissionReadWrite); err != nil {
		return err
	}
	return s.userManager.AllowAccess(userB, topic, user.PermissionReadWrite)
}

func mapFriendErr(err error) error {
	switch {
	case errors.Is(err, chatgroup.ErrNotFound):
		return errHTTPNotFound
	case errors.Is(err, chatgroup.ErrForbidden):
		return errHTTPForbidden
	case errors.Is(err, chatgroup.ErrAlreadyFriends):
		return errHTTPBadRequest.Wrap("already friends")
	case errors.Is(err, chatgroup.ErrAlreadyRequested):
		return errHTTPBadRequest.Wrap("%s", err.Error())
	case errors.Is(err, chatgroup.ErrInvalidArgument):
		return errHTTPBadRequest.Wrap("%s", err.Error())
	default:
		return err
	}
}
