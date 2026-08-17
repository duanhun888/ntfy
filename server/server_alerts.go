package server

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"regexp"
	"strings"
	"time"

	"heckel.io/ntfy/v2/chatgroup"
	"heckel.io/ntfy/v2/log"
	"heckel.io/ntfy/v2/util"
)

var (
	apiAlertRoutesPath        = "/v1/alert-routes"
	apiAlertRoutesSingleRegex = regexp.MustCompile(`^/v1/alert-routes/(ar_[-_A-Za-z0-9]+)$`)
	apiAlertTriggerRegex      = regexp.MustCompile(`^/alert/([A-Za-z0-9_-]+)$`)
	apiAlertDeliveriesPath    = "/v1/alert-deliveries"
	apiAlertDeliveryStatsPath = "/v1/alert-deliveries/stats"
)

type apiAlertRouteCreateRequest struct {
	BizType      string `json:"biz_type"`
	Name         string `json:"name"`
	GroupID      string `json:"group_id"`
	WeComWebhook string `json:"wecom_webhook"`
}

type apiAlertRouteUpdateRequest struct {
	Name         string `json:"name"`
	GroupID      string `json:"group_id"`
	WeComWebhook string `json:"wecom_webhook"`
	Enabled      *bool  `json:"enabled"`
}

type apiAlertRouteCreateResponse struct {
	*chatgroup.AlertRoute
	TriggerURL string `json:"trigger_url"`
}

type apiAlertTriggerResponse struct {
	OK       bool   `json:"ok"`
	BizType  string `json:"biz_type"`
	AppOK    *bool  `json:"app_ok,omitempty"`
	WeComOK  *bool  `json:"wecom_ok,omitempty"`
	Message  string `json:"message,omitempty"`
	WeComErr string `json:"wecom_error,omitempty"`
}

func (s *Server) handleAlertRoutesList(w http.ResponseWriter, r *http.Request, v *visitor) error {
	u := v.User()
	var routes []*chatgroup.AlertRoute
	var err error
	if u.IsAdmin() {
		routes, err = s.chatGroups.AllAlertRoutes()
	} else {
		routes, err = s.chatGroups.AlertRoutesForUser(u.ID)
	}
	if err != nil {
		return err
	}
	return s.writeJSON(w, routes)
}

func (s *Server) handleAlertRouteCreate(w http.ResponseWriter, r *http.Request, v *visitor) error {
	u := v.User()
	req, err := readJSONWithLimit[apiAlertRouteCreateRequest](r.Body, jsonBodyBytesLimit, false)
	if err != nil {
		return err
	}
	bizType := strings.TrimSpace(req.BizType)
	name := strings.TrimSpace(req.Name)
	groupID := strings.TrimSpace(req.GroupID)
	wecom := strings.TrimSpace(req.WeComWebhook)
	if name == "" {
		name = bizType
	}
	if groupID != "" {
		if err := s.requireGroupManage(groupID, v); err != nil {
			return err
		}
	}
	if wecom != "" && !isHTTPURL(wecom) {
		return errHTTPBadRequest.Wrap("wecom_webhook must be http(s) URL")
	}
	route, err := s.chatGroups.CreateAlertRoute(bizType, name, u.ID, groupID, wecom)
	if err != nil {
		return mapChatErr(err)
	}
	return s.writeJSON(w, &apiAlertRouteCreateResponse{
		AlertRoute: route,
		TriggerURL: s.alertTriggerURL(r, route.BizType),
	})
}

func (s *Server) handleAlertRouteGet(w http.ResponseWriter, r *http.Request, v *visitor) error {
	id := apiAlertRoutesSingleRegex.FindStringSubmatch(r.URL.Path)[1]
	route, err := s.chatGroups.AlertRoute(id)
	if err != nil {
		return mapChatErr(err)
	}
	if err := s.requireAlertRouteAccess(route, v); err != nil {
		return err
	}
	return s.writeJSON(w, route)
}

func (s *Server) handleAlertRouteUpdate(w http.ResponseWriter, r *http.Request, v *visitor) error {
	id := apiAlertRoutesSingleRegex.FindStringSubmatch(r.URL.Path)[1]
	route, err := s.chatGroups.AlertRoute(id)
	if err != nil {
		return mapChatErr(err)
	}
	if err := s.requireAlertRouteAccess(route, v); err != nil {
		return err
	}
	req, err := readJSONWithLimit[apiAlertRouteUpdateRequest](r.Body, jsonBodyBytesLimit, false)
	if err != nil {
		return err
	}
	name := strings.TrimSpace(req.Name)
	if name == "" {
		name = route.Name
	}
	groupID := strings.TrimSpace(req.GroupID)
	wecom := strings.TrimSpace(req.WeComWebhook)
	if groupID != "" {
		if err := s.requireGroupManage(groupID, v); err != nil {
			return err
		}
	}
	if wecom != "" && !isHTTPURL(wecom) {
		return errHTTPBadRequest.Wrap("wecom_webhook must be http(s) URL")
	}
	enabled := route.Enabled
	if req.Enabled != nil {
		enabled = *req.Enabled
	}
	updated, err := s.chatGroups.UpdateAlertRoute(id, name, groupID, wecom, enabled)
	if err != nil {
		return mapChatErr(err)
	}
	return s.writeJSON(w, updated)
}

func (s *Server) handleAlertRouteDelete(w http.ResponseWriter, r *http.Request, v *visitor) error {
	id := apiAlertRoutesSingleRegex.FindStringSubmatch(r.URL.Path)[1]
	route, err := s.chatGroups.AlertRoute(id)
	if err != nil {
		return mapChatErr(err)
	}
	if err := s.requireAlertRouteAccess(route, v); err != nil {
		return err
	}
	if err := s.chatGroups.DeleteAlertRoute(id); err != nil {
		return mapChatErr(err)
	}
	return s.writeJSON(w, newSuccessResponse())
}

func (s *Server) handleAlertTrigger(w http.ResponseWriter, r *http.Request, v *visitor) error {
	bizType := apiAlertTriggerRegex.FindStringSubmatch(r.URL.Path)[1]
	route, err := s.chatGroups.AlertRouteByBizType(bizType)
	if err != nil {
		return mapChatErr(err)
	}
	token := alertTokenFromRequest(r)
	if token == "" || token != route.Token {
		return errHTTPUnauthorized
	}
	if !route.Enabled {
		return errHTTPForbidden.Wrap("route disabled")
	}

	peeked, err := util.Peek(r.Body, s.config.MessageSizeLimit)
	if err != nil {
		return err
	}
	msgBody, title := normalizeHookBody(peeked.PeekedBytes, route.Name)

	resp := &apiAlertTriggerResponse{
		OK:      true,
		BizType: route.BizType,
		Message: string(msgBody),
	}

	if route.GroupID != "" {
		ok, pubErr := s.publishAlertToGroup(r, v, route, msgBody, title)
		resp.AppOK = &ok
		if pubErr != nil {
			log.Tag("alert").Warn("app publish failed for %s: %v", route.BizType, pubErr)
			resp.OK = false
		}
	}

	if route.WeComWebhook != "" {
		ok, wecomErr := postWeComText(route.WeComWebhook, string(msgBody))
		resp.WeComOK = &ok
		if wecomErr != nil {
			log.Tag("alert").Warn("wecom publish failed for %s: %v", route.BizType, wecomErr)
			resp.WeComErr = wecomErr.Error()
			if route.GroupID == "" {
				resp.OK = false
			}
		}
	}

	d := &chatgroup.AlertDelivery{
		RouteID:     route.ID,
		BizType:     route.BizType,
		OwnerUserID: route.OwnerUserID,
		Message:     string(msgBody),
		AppOK:       resp.AppOK,
		WeComOK:     resp.WeComOK,
		WeComError:  resp.WeComErr,
	}
	if err := s.chatGroups.InsertDelivery(d); err != nil {
		log.Tag("alert").Warn("failed to record delivery for %s: %v", route.BizType, err)
	}

	return s.writeJSON(w, resp)
}

func (s *Server) handleAlertDeliveriesList(w http.ResponseWriter, r *http.Request, v *visitor) error {
	u := v.User()
	lim := 100
	if raw := strings.TrimSpace(r.URL.Query().Get("limit")); raw != "" {
		if n, err := parsePositiveInt(raw, 100, 500); err == nil {
			lim = n
		}
	}
	bizType := strings.TrimSpace(r.URL.Query().Get("biz_type"))
	var list []*chatgroup.AlertDelivery
	var err error
	if u.IsAdmin() {
		list, err = s.chatGroups.AllDeliveries(lim, bizType)
	} else {
		list, err = s.chatGroups.DeliveriesForUser(u.ID, lim, bizType)
	}
	if err != nil {
		return err
	}
	return s.writeJSON(w, list)
}

func (s *Server) handleAlertDeliveryStats(w http.ResponseWriter, r *http.Request, v *visitor) error {
	u := v.User()
	since := time.Now().Add(-24 * time.Hour).Unix()
	if raw := strings.TrimSpace(r.URL.Query().Get("since")); raw != "" {
		if n, err := parsePositiveInt(raw, int(since), int(time.Now().Unix())); err == nil {
			since = int64(n)
		}
	}
	ownerFilter := ""
	if !u.IsAdmin() {
		ownerFilter = u.ID
	}
	stats, err := s.chatGroups.DeliveryStatsSince(since, ownerFilter)
	if err != nil {
		return err
	}
	return s.writeJSON(w, stats)
}

func parsePositiveInt(s string, def, max int) (int, error) {
	n := 0
	if s == "" {
		return def, fmt.Errorf("empty")
	}
	for _, c := range s {
		if c < '0' || c > '9' {
			return def, fmt.Errorf("not an int")
		}
		n = n*10 + int(c-'0')
		if n > max {
			return max, nil
		}
	}
	if n <= 0 {
		return def, nil
	}
	return n, nil
}

func (s *Server) publishAlertToGroup(r *http.Request, v *visitor, route *chatgroup.AlertRoute, msgBody []byte, title string) (bool, error) {
	g, err := s.chatGroups.Group(route.GroupID)
	if err != nil {
		return false, mapChatErr(err)
	}
	owner, err := s.userManager.UserByID(g.OwnerUserID)
	if err != nil {
		return false, errHTTPUnauthorized
	}
	ov := s.visitor(v.IP(), owner)
	t, err := s.topicFromID(ov, g.Topic)
	if err != nil {
		return false, err
	}
	r.Body = io.NopCloser(bytes.NewReader(msgBody))
	if title != "" {
		r.Header.Set("X-Title", title)
	}
	// Same as webhook bots: /alert/<biz> must not be treated as /topic/<sequence_id>.
	r.URL.Path = "/" + g.Topic
	r = withContext(r, map[contextKey]any{
		contextTopic:       t,
		contextRateVisitor: ov,
	})
	if _, err := s.handlePublishInternal(r, ov); err != nil {
		return false, err
	}
	return true, nil
}

func (s *Server) requireAlertRouteAccess(route *chatgroup.AlertRoute, v *visitor) error {
	u := v.User()
	if u == nil {
		return errHTTPUnauthorized
	}
	if u.IsAdmin() || u.ID == route.OwnerUserID {
		return nil
	}
	return errHTTPForbidden
}

func (s *Server) alertTriggerURL(r *http.Request, bizType string) string {
	base := strings.TrimRight(s.config.BaseURL, "/")
	if base == "" {
		base = "http://" + r.Host
	}
	return base + "/alert/" + bizType
}

func alertTokenFromRequest(r *http.Request) string {
	if t := strings.TrimSpace(r.Header.Get("X-Alert-Token")); t != "" {
		return t
	}
	auth := r.Header.Get("Authorization")
	if strings.HasPrefix(strings.ToLower(auth), "bearer ") {
		return strings.TrimSpace(auth[7:])
	}
	return strings.TrimSpace(r.URL.Query().Get("token"))
}

func isHTTPURL(u string) bool {
	return strings.HasPrefix(u, "https://") || strings.HasPrefix(u, "http://")
}

func postWeComText(webhookURL, content string) (bool, error) {
	payload := map[string]any{
		"msgtype": "text",
		"text": map[string]string{
			"content": content,
		},
	}
	body, err := json.Marshal(payload)
	if err != nil {
		return false, err
	}
	ctx, cancel := context.WithTimeout(context.Background(), 8*time.Second)
	defer cancel()
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, webhookURL, bytes.NewReader(body))
	if err != nil {
		return false, err
	}
	req.Header.Set("Content-Type", "application/json")
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return false, err
	}
	defer resp.Body.Close()
	respBody, _ := io.ReadAll(io.LimitReader(resp.Body, 4096))
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return false, fmt.Errorf("wecom http %d: %s", resp.StatusCode, string(respBody))
	}
	// WeCom returns {"errcode":0,...} on success
	var wr struct {
		ErrCode int    `json:"errcode"`
		ErrMsg  string `json:"errmsg"`
	}
	if err := json.Unmarshal(respBody, &wr); err == nil && wr.ErrCode != 0 {
		return false, fmt.Errorf("wecom: %s (%d)", wr.ErrMsg, wr.ErrCode)
	}
	return true, nil
}
