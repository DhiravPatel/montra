package api_test

import (
	"encoding/json"
	"net/http"
	"sort"
	"strconv"
	"strings"
	"testing"

	"github.com/google/uuid"

	"montra/backend/internal/app"
	"montra/backend/internal/categories"
	"montra/backend/internal/platform/config"
	"montra/backend/internal/testutil/apitest"
)

// Organize screens (categories, rules, tags, merchants): fixes reported by
// the web client while building them.

// orgCoded asserts a coded error: HTTP status, error.code and
// error.details[0].code. It returns error.details[0].params.
func orgCoded(t *testing.T, r *apitest.Response, status int, code, reason string) map[string]any {
	t.Helper()
	if r.Status != status || r.ErrorCode() != code {
		t.Fatalf("want %d %s/%s, got %d: %s", status, code, reason, r.Status, r.Raw)
	}
	e, _ := r.Body["error"].(map[string]any)
	d, _ := e["details"].([]any)
	if len(d) == 0 {
		t.Fatalf("error has no details: %s", r.Raw)
	}
	first, _ := d[0].(map[string]any)
	if first["code"] != reason {
		t.Fatalf("details[0].code = %v, want %s: %s", first["code"], reason, r.Raw)
	}
	params, _ := first["params"].(map[string]any)
	return params
}

// orgVersionConflict asserts 409 VERSION_CONFLICT.
func orgVersionConflict(t *testing.T, r *apitest.Response) {
	t.Helper()
	if r.Status != http.StatusConflict || r.ErrorCode() != "VERSION_CONFLICT" {
		t.Fatalf("want 409 VERSION_CONFLICT, got %d: %s", r.Status, r.Raw)
	}
}

// orgAffected asserts a merge result: the preview flag and exactly the
// expected typed counts.
func orgAffected(t *testing.T, res map[string]any, preview bool, want map[string]float64) {
	t.Helper()
	aff, _ := res["affected"].(map[string]any)
	if res["preview"] != preview || len(aff) != len(want) {
		t.Fatalf("merge result = %v, want preview=%v and counts %v", res, preview, want)
	}
	for k, v := range want {
		if aff[k] != v {
			t.Fatalf("affected[%s] = %v, want %v (all: %v)", k, aff[k], v, aff)
		}
	}
}

// orgNames lists merchant names of one page.
func orgNames(t *testing.T, c *apitest.Client, path string) []string {
	t.Helper()
	return names(c.Do(t, http.MethodGet, path, nil).Expect(t, http.StatusOK).List(), "name")
}

// orgPages follows meta.next_cursor through every page of a list.
func orgPages(t *testing.T, c *apitest.Client, path string, limit int) []map[string]any {
	t.Helper()
	var out []map[string]any
	cursor := ""
	for page := 0; page < 50; page++ {
		p := path + "&limit=" + strconv.Itoa(limit)
		if cursor != "" {
			p += "&cursor=" + cursor
		}
		r := c.Do(t, http.MethodGet, p, nil).Expect(t, http.StatusOK)
		for _, x := range r.List() {
			out = append(out, x.(map[string]any))
		}
		meta := r.Body["meta"].(map[string]any)
		next, _ := meta["next_cursor"].(string)
		if more, _ := meta["has_more"].(bool); more != (next != "") {
			t.Fatalf("has_more = %v with next_cursor %q", meta["has_more"], next)
		}
		if next == "" {
			return out
		}
		if n := len(r.List()); n != limit {
			t.Fatalf("a page before the last has %d items, want %d", n, limit)
		}
		cursor = next
	}
	t.Fatal("pagination did not end")
	return nil
}

func TestOrganizeCategoriesGetDeleteCodesTypedMergeAndColors(t *testing.T) {
	s := apitest.New(t, nil)
	c, _ := s.Login(t, s.Register(t, "organizer"))
	acct := createAccount(t, c, map[string]any{"name": "Bank", "account_type": "bank", "currency": "INR", "opening_balance": "5000"})["id"].(string)
	hid := c.Do(t, http.MethodPost, "/categories", map[string]any{"name": "Hobbies", "kind": "expense", "color": "#123456", "icon": "palette"}).
		Expect(t, http.StatusCreated).Data()["id"].(string)
	painting := c.Do(t, http.MethodPost, "/categories", map[string]any{"name": "Painting", "kind": "expense", "parent_id": hid}).
		Expect(t, http.StatusCreated).Data()["id"].(string)
	lid := c.Do(t, http.MethodPost, "/categories", map[string]any{"name": "Leisure", "kind": "expense", "color": "#654321"}).
		Expect(t, http.StatusCreated).Data()["id"].(string)

	// GET /categories/{id} returns the list DTO; others' categories are 404.
	got := c.Do(t, http.MethodGet, "/categories/"+hid, nil).Expect(t, http.StatusOK).Data()
	if got["name"] != "Hobbies" || got["status"] != "active" || got["color"] != "#123456" || got["icon"] != "palette" || got["version"] != 1.0 {
		t.Fatalf("get category = %v", got)
	}
	other, _ := s.Login(t, s.Register(t, "outsider"))
	other.Do(t, http.MethodGet, "/categories/"+hid, nil).Expect(t, http.StatusNotFound)
	c.Do(t, http.MethodGet, "/categories/"+uuid.NewString(), nil).Expect(t, http.StatusNotFound)

	// Duplicate names at one level (case-insensitive) are 409 name_taken.
	if p := orgCoded(t, c.Do(t, http.MethodPost, "/categories", map[string]any{"name": " leisure ", "kind": "income"}), http.StatusConflict,
		"CONFLICT", "name_taken"); p["name"] != "leisure" {
		t.Fatalf("name_taken params = %v", p)
	}
	if p := orgCoded(t, c.Do(t, http.MethodPatch, "/categories/"+hid, map[string]any{"version": 1, "name": "LEISURE"}), http.StatusConflict,
		"CONFLICT", "name_taken"); p["name"] != "LEISURE" {
		t.Fatalf("name_taken params = %v", p)
	}

	// References: two transactions (one deleted), the subcategory, a rule and
	// a merchant's default category.
	t1 := createTx(t, c, map[string]any{"type": "expense", "account_id": acct, "amount": "120", "category_id": hid, "merchant_name": "Art Supply Co"})
	t2 := createTx(t, c, map[string]any{"type": "expense", "account_id": acct, "amount": "80", "category_id": hid})
	c.Do(t, http.MethodDelete, "/transactions/"+t2["id"].(string), nil).Expect(t, http.StatusOK)
	rule := c.Do(t, http.MethodPost, "/category-rules", map[string]any{"name": "Brushes", "match_field": "description", "match_type": "contains",
		"pattern": "brush", "priority": 10, "set_category_id": hid}).Expect(t, http.StatusCreated).Data()
	merchant := t1["merchant"].(map[string]any)["id"].(string)
	mer := c.Do(t, http.MethodPatch, "/merchants/"+merchant, map[string]any{"default_category_id": hid}).Expect(t, http.StatusOK).Data()

	// Deleting a used category: 409 category_in_use with the non-zero counts.
	params := orgCoded(t, c.Do(t, http.MethodDelete, "/categories/"+hid, nil), http.StatusConflict, "CONFLICT", "category_in_use")
	if len(params) != 4 || params["transactions"] != "2" || params["subcategories"] != "1" || params["rules"] != "1" || params["merchants"] != "1" {
		t.Fatalf("category_in_use params = %v", params)
	}

	// Merge preview and merge report the same typed counts.
	want := map[string]float64{"transactions": 2, "subcategories": 1, "rules": 1, "budget_allocations": 0, "recurring_rules": 0, "bills": 0,
		"subscriptions": 0, "merchants": 1, "budget_filters": 0}
	merge := map[string]any{"source_ids": []string{hid}, "target_id": lid, "preview": true}
	orgAffected(t, c.Do(t, http.MethodPost, "/categories/merge", merge).Expect(t, http.StatusOK).Data(), true, want)
	if g := c.Do(t, http.MethodGet, "/categories/"+hid, nil).Expect(t, http.StatusOK).Data(); g["status"] != "active" {
		t.Fatalf("preview changed the category: %v", g)
	}
	merge["preview"] = false
	orgAffected(t, c.Do(t, http.MethodPost, "/categories/merge", merge).Expect(t, http.StatusOK).Data(), false, want)

	// The merged category points to its successor; moved records have a new
	// version.
	if g := c.Do(t, http.MethodGet, "/categories/"+hid, nil).Expect(t, http.StatusOK).Data(); g["status"] != "merged" || g["merged_into_id"] != lid {
		t.Fatalf("merged category = %v", g)
	}
	if g := c.Do(t, http.MethodGet, "/categories/"+painting, nil).Expect(t, http.StatusOK).Data(); g["parent_id"] != lid || g["version"] != 2.0 {
		t.Fatalf("subcategory after merge = %v", g)
	}
	for _, x := range c.Do(t, http.MethodGet, "/category-rules", nil).Expect(t, http.StatusOK).List() {
		if r := x.(map[string]any); r["id"] == rule["id"] && (r["set_category_id"] != lid || r["version"] != 2.0) {
			t.Fatalf("rule after merge = %v", r)
		}
	}
	if g := c.Do(t, http.MethodGet, "/merchants/"+merchant, nil).Expect(t, http.StatusOK).Data(); g["default_category_id"] != lid ||
		g["version"] != mer["version"].(float64)+1 {
		t.Fatalf("merchant after merge = %v (before %v)", g, mer)
	}

	// Existing domain rule codes are unchanged.
	gaming := c.Do(t, http.MethodPost, "/categories", map[string]any{"name": "Gaming", "kind": "expense", "parent_id": lid}).Expect(t, http.StatusCreated).Data()["id"]
	orgCoded(t, c.Do(t, http.MethodPost, "/categories", map[string]any{"name": "Consoles", "kind": "expense", "parent_id": gaming}),
		http.StatusUnprocessableEntity, "DOMAIN_RULE_VIOLATION", "category_depth")
	orgCoded(t, c.Do(t, http.MethodPost, "/categories/merge", map[string]any{"source_ids": []string{lid}, "target_id": gaming, "preview": true}),
		http.StatusUnprocessableEntity, "DOMAIN_RULE_VIOLATION", "merge_target_must_be_top_level")

	// Colors and icons can be removed: clear_color, or an empty string (the
	// partial-PATCH convention for text). A new color plus clear_color is
	// refused. Version is still required and checked.
	lv := c.Do(t, http.MethodGet, "/categories/"+lid, nil).Expect(t, http.StatusOK).Data()["version"]
	cleared := c.Do(t, http.MethodPatch, "/categories/"+lid, map[string]any{"version": lv, "clear_color": true}).Expect(t, http.StatusOK).Data()
	if _, has := cleared["color"]; has || cleared["name"] != "Leisure" || cleared["version"] != lv.(float64)+1 {
		t.Fatalf("clear_color = %v", cleared)
	}
	orgVersionConflict(t, c.Do(t, http.MethodPatch, "/categories/"+lid, map[string]any{"version": lv, "color": "#000000"}))
	r := c.Do(t, http.MethodPatch, "/categories/"+lid, map[string]any{"version": cleared["version"], "color": "#000000", "clear_color": true})
	if r.ErrorCode() != "VALIDATION_ERROR" || firstDetailField(r) != "body.clear_color" {
		t.Fatalf("color plus clear_color: %s", r.Raw)
	}
	recolored := c.Do(t, http.MethodPatch, "/categories/"+lid, map[string]any{"version": cleared["version"], "color": "#00AA00", "icon": "sports_esports"}).
		Expect(t, http.StatusOK).Data()
	if recolored["color"] != "#00AA00" || recolored["icon"] != "sports_esports" {
		t.Fatalf("recolor = %v", recolored)
	}
	emptied := c.Do(t, http.MethodPatch, "/categories/"+lid, map[string]any{"version": recolored["version"], "color": "", "icon": ""}).
		Expect(t, http.StatusOK).Data()
	if _, has := emptied["color"]; has {
		t.Fatalf("empty color did not clear: %v", emptied)
	}
	if _, has := emptied["icon"]; has {
		t.Fatalf("empty icon did not clear: %v", emptied)
	}
	c.Do(t, http.MethodPatch, "/categories/"+lid, map[string]any{"version": emptied["version"], "color": "blue"}).Expect(t, http.StatusUnprocessableEntity)
}

func TestOrganizeRulesVersionCurrencyAndApplySavedRule(t *testing.T) {
	s := apitest.New(t, nil)
	c, _ := s.Login(t, s.Register(t, "ruler"))
	acct := createAccount(t, c, map[string]any{"name": "Bank", "account_type": "bank", "currency": "INR", "opening_balance": "50000"})["id"].(string)
	// The transactions predate the rules, so they stay uncategorized.
	big := createTx(t, c, map[string]any{"type": "expense", "account_id": acct, "amount": "1500", "description": "Gym membership"})
	small := createTx(t, c, map[string]any{"type": "expense", "account_id": acct, "amount": "200", "description": "Gym shake"})
	createTx(t, c, map[string]any{"type": "expense", "account_id": acct, "amount": "500", "description": "Book"})
	fitness := c.Do(t, http.MethodPost, "/categories", map[string]any{"name": "Fitness", "kind": "expense"}).Expect(t, http.StatusCreated).Data()["id"].(string)

	// An unknown category is reported on the field that was sent.
	bad := map[string]any{"name": "Bad", "match_field": "any", "match_type": "contains", "pattern": "x", "priority": 1, "set_category_id": uuid.NewString()}
	if r := c.Do(t, http.MethodPost, "/category-rules", bad); r.ErrorCode() != "VALIDATION_ERROR" || firstDetailField(r) != "body.set_category_id" {
		t.Fatalf("unknown category on create: %s", r.Raw)
	}
	if r := c.Do(t, http.MethodPost, "/category-rules/preview", map[string]any{"rule": bad, "only_uncategorized": false}); firstDetailField(r) != "body.rule.set_category_id" {
		t.Fatalf("unknown category on preview: %s", r.Raw)
	}
	bad["set_category_id"], bad["amount_min"] = fitness, "1.234"
	if r := c.Do(t, http.MethodPost, "/category-rules/apply", map[string]any{"rule": bad, "only_uncategorized": false}); firstDetailField(r) != "body.rule.amount_min" {
		t.Fatalf("invalid amount on apply: %s", r.Raw)
	}

	// Amount bounds come with their currency (the base currency unless sent);
	// without an amount condition currency is explicitly null.
	gym := c.Do(t, http.MethodPost, "/category-rules", map[string]any{"name": "Gym", "match_field": "description", "match_type": "contains",
		"pattern": "gym", "amount_min": "1000", "priority": 10, "set_category_id": fitness}).Expect(t, http.StatusCreated).Data()
	if gym["amount_min"] != "1000.00" || gym["currency"] != "INR" || gym["version"] != 1.0 {
		t.Fatalf("rule with a base-currency bound = %v", gym)
	}
	yen := c.Do(t, http.MethodPost, "/category-rules", map[string]any{"name": "Yen", "match_field": "any", "match_type": "contains",
		"pattern": "tokyo", "amount_max": "5000", "currency": "JPY", "priority": 20, "set_category_id": fitness}).Expect(t, http.StatusCreated).Data()
	if yen["amount_max"] != "5000" || yen["currency"] != "JPY" || yen["amount_min"] != nil {
		t.Fatalf("rule with a JPY bound = %v", yen)
	}
	plain := c.Do(t, http.MethodPost, "/category-rules", map[string]any{"name": "Plain", "match_field": "merchant", "match_type": "equals",
		"pattern": "Corner Shop", "priority": 30, "set_category_id": fitness}).Expect(t, http.StatusCreated)
	if cur, present := plain.Data()["currency"]; !present || cur != nil {
		t.Fatalf("a rule without amounts must return currency null: %s", plain.Raw)
	}
	listed := 0
	for _, x := range c.Do(t, http.MethodGet, "/category-rules", nil).Expect(t, http.StatusOK).List() {
		r := x.(map[string]any)
		if r["id"] == yen["id"] && r["currency"] == "JPY" && r["amount_max"] == "5000" && r["version"] == 1.0 {
			listed++
		}
	}
	if listed != 1 {
		t.Fatal("the listed JPY rule lost its currency or version")
	}

	// PUT checks version when sent; without it the replace still works.
	gid := gym["id"].(string)
	body := map[string]any{"name": "Gym", "match_field": "description", "match_type": "contains", "pattern": "gym", "amount_min": "1000",
		"set_category_id": fitness, "priority": 5, "version": 1}
	upd := c.Do(t, http.MethodPut, "/category-rules/"+gid, body).Expect(t, http.StatusOK).Data()
	if upd["version"] != 2.0 || upd["priority"] != 5.0 || upd["currency"] != "INR" || upd["amount_min"] != "1000.00" {
		t.Fatalf("versioned replace = %v", upd)
	}
	orgVersionConflict(t, c.Do(t, http.MethodPut, "/category-rules/"+gid, body))
	delete(body, "version")
	body["priority"] = 7
	if upd = c.Do(t, http.MethodPut, "/category-rules/"+gid, body).Expect(t, http.StatusOK).Data(); upd["version"] != 3.0 || upd["priority"] != 7.0 {
		t.Fatalf("replace without version = %v", upd)
	}
	c.Do(t, http.MethodPut, "/category-rules/"+uuid.NewString(), body).Expect(t, http.StatusNotFound)

	// Apply a saved rule by ID: same result as /category-rules/apply.
	res := c.Do(t, http.MethodPost, "/category-rules/"+gid+"/apply", map[string]any{"only_uncategorized": true}).Expect(t, http.StatusOK).Data()
	sample := res["sample"].([]any)
	if res["match_count"] != 1.0 || len(sample) != 1 || sample[0].(map[string]any)["id"] != big["id"] ||
		sample[0].(map[string]any)["category"].(map[string]any)["id"] != fitness {
		t.Fatalf("apply saved rule = %v", res)
	}
	if tx := c.Do(t, http.MethodGet, "/transactions/"+small["id"].(string), nil).Expect(t, http.StatusOK).Data(); tx["category"] != nil {
		t.Fatalf("a transaction below the minimum was categorized: %v", tx["category"])
	}
	events := c.Do(t, http.MethodGet, "/transactions/"+big["id"].(string)+"/audit", nil).Expect(t, http.StatusOK).List()
	last := events[len(events)-1].(map[string]any)
	if ch, _ := last["changes"].(map[string]any); last["action"] != "rule_categorized" || ch["rule_id"] != gid || ch["category_id"] != fitness {
		t.Fatalf("audit of a saved-rule apply = %v", last)
	}
	if again := c.Do(t, http.MethodPost, "/category-rules/"+gid+"/apply", map[string]any{"only_uncategorized": true}).Expect(t, http.StatusOK).Data(); again["match_count"] != 0.0 {
		t.Fatalf("only_uncategorized re-apply = %v", again)
	}
	c.Do(t, http.MethodPost, "/category-rules/"+gid+"/apply", map[string]any{}).Expect(t, http.StatusUnprocessableEntity)
	// The body-based endpoint keeps working.
	byBody := c.Do(t, http.MethodPost, "/category-rules/apply", map[string]any{"only_uncategorized": true, "rule": map[string]any{"name": "Books",
		"match_field": "description", "match_type": "contains", "pattern": "book", "priority": 40, "set_category_id": fitness}}).Expect(t, http.StatusOK).Data()
	if byBody["match_count"] != 1.0 {
		t.Fatalf("apply with a rule body = %v", byBody)
	}

	// Others' and missing rules are 404; an archived target category is refused
	// like on the body-based endpoint.
	other, _ := s.Login(t, s.Register(t, "rulethief"))
	other.Do(t, http.MethodPost, "/category-rules/"+gid+"/apply", map[string]any{"only_uncategorized": false}).Expect(t, http.StatusNotFound)
	other.Do(t, http.MethodPut, "/category-rules/"+gid, body).Expect(t, http.StatusNotFound)
	c.Do(t, http.MethodPost, "/category-rules/"+uuid.NewString()+"/apply", map[string]any{"only_uncategorized": true}).Expect(t, http.StatusNotFound)
	c.Do(t, http.MethodPost, "/categories/"+fitness+"/archive", nil).Expect(t, http.StatusOK)
	orgCoded(t, c.Do(t, http.MethodPost, "/category-rules/"+gid+"/apply", map[string]any{"only_uncategorized": false}),
		http.StatusUnprocessableEntity, "DOMAIN_RULE_VIOLATION", "rule_category_unavailable")
}

func TestOrganizeTagsVersionsColorsAndNames(t *testing.T) {
	s := apitest.New(t, nil)
	c, _ := s.Login(t, s.Register(t, "tagger"))
	acct := createAccount(t, c, map[string]any{"name": "Wallet", "account_type": "cash", "currency": "INR", "opening_balance": "1000"})["id"].(string)
	trip := c.Do(t, http.MethodPost, "/tags", map[string]any{"name": "Trip", "color": "#112233"}).Expect(t, http.StatusCreated).Data()
	tid := trip["id"].(string)
	if trip["version"] != 1.0 || trip["color"] != "#112233" || trip["usage_count"] != 0.0 {
		t.Fatalf("created tag = %v", trip)
	}
	work := c.Do(t, http.MethodPost, "/tags", map[string]any{"name": "Work"}).Expect(t, http.StatusCreated).Data()["id"].(string)

	// Duplicate names (normalized) are 409 name_taken on create and rename.
	if p := orgCoded(t, c.Do(t, http.MethodPost, "/tags", map[string]any{"name": "  trip "}), http.StatusConflict, "CONFLICT", "name_taken"); p["name"] != "trip" {
		t.Fatalf("name_taken params = %v", p)
	}
	if p := orgCoded(t, c.Do(t, http.MethodPatch, "/tags/"+work, map[string]any{"name": "TRIP"}), http.StatusConflict, "CONFLICT", "name_taken"); p["name"] != "TRIP" {
		t.Fatalf("name_taken params = %v", p)
	}

	// PATCH checks version when sent and returns the real usage count.
	createTx(t, c, map[string]any{"type": "expense", "account_id": acct, "amount": "10", "tag_ids": []string{tid}})
	renamed := c.Do(t, http.MethodPatch, "/tags/"+tid, map[string]any{"name": "Trips", "version": 1}).Expect(t, http.StatusOK).Data()
	if renamed["name"] != "Trips" || renamed["version"] != 2.0 || renamed["usage_count"] != 1.0 || renamed["color"] != "#112233" {
		t.Fatalf("versioned rename = %v", renamed)
	}
	orgVersionConflict(t, c.Do(t, http.MethodPatch, "/tags/"+tid, map[string]any{"name": "Old", "version": 1}))

	// clear_color removes the color (no version sent: not enforced), so does
	// an empty string; a new color plus clear_color is refused.
	cleared := c.Do(t, http.MethodPatch, "/tags/"+tid, map[string]any{"clear_color": true}).Expect(t, http.StatusOK).Data()
	if _, has := cleared["color"]; has || cleared["version"] != 3.0 || cleared["name"] != "Trips" {
		t.Fatalf("clear_color = %v", cleared)
	}
	if r := c.Do(t, http.MethodPatch, "/tags/"+tid, map[string]any{"color": "#445566", "clear_color": true}); firstDetailField(r) != "body.clear_color" {
		t.Fatalf("color plus clear_color: %s", r.Raw)
	}
	c.Do(t, http.MethodPatch, "/tags/"+work, map[string]any{"color": "#445566"}).Expect(t, http.StatusOK)
	if w := c.Do(t, http.MethodPatch, "/tags/"+work, map[string]any{"color": ""}).Expect(t, http.StatusOK).Data(); w["color"] != nil {
		t.Fatalf("empty color did not clear: %v", w)
	}
	c.Do(t, http.MethodPatch, "/tags/"+tid, map[string]any{"color": "red"}).Expect(t, http.StatusUnprocessableEntity)

	// Archiving is versioned; using the name again restores the tag as a new
	// version, while using an active tag leaves its version alone.
	archived := c.Do(t, http.MethodPatch, "/tags/"+tid, map[string]any{"archived": true, "version": 3}).Expect(t, http.StatusOK).Data()
	if archived["archived_at"] == nil || archived["version"] != 4.0 {
		t.Fatalf("archive = %v", archived)
	}
	tagState := func() map[string]any {
		t.Helper()
		for _, x := range c.Do(t, http.MethodGet, "/tags", nil).Expect(t, http.StatusOK).List() {
			if x.(map[string]any)["id"] == tid {
				return x.(map[string]any)
			}
		}
		t.Fatal("tag missing from the list")
		return nil
	}
	createTx(t, c, map[string]any{"type": "expense", "account_id": acct, "amount": "11", "tag_names": []string{"trips"}})
	if g := tagState(); g["archived_at"] != nil || g["version"] != 5.0 || g["usage_count"] != 2.0 {
		t.Fatalf("tag restored by use = %v", g)
	}
	createTx(t, c, map[string]any{"type": "expense", "account_id": acct, "amount": "12", "tag_names": []string{"Trips"}})
	if g := tagState(); g["version"] != 5.0 || g["usage_count"] != 3.0 {
		t.Fatalf("using an active tag changed its version: %v", g)
	}

	c.Do(t, http.MethodPatch, "/tags/"+uuid.NewString(), map[string]any{"name": "Nope"}).Expect(t, http.StatusNotFound)
	other, _ := s.Login(t, s.Register(t, "tagthief"))
	other.Do(t, http.MethodPatch, "/tags/"+tid, map[string]any{"name": "Mine"}).Expect(t, http.StatusNotFound)
}

func TestOrganizeMerchantsPagingStatusVersionsAndMergePreview(t *testing.T) {
	s := apitest.New(t, nil)
	c, _ := s.Login(t, s.Register(t, "shopper"))
	acct := createAccount(t, c, map[string]any{"name": "Bank", "account_type": "bank", "currency": "INR", "opening_balance": "90000"})["id"].(string)
	mid := map[string]string{}
	for _, name := range []string{"Amazon", "Amzn Mktp", "AMZN Prime", "Kamal Stores", "Zeta Store"} {
		tx := createTx(t, c, map[string]any{"type": "expense", "account_id": acct, "amount": "100", "merchant_name": name})
		mid[name] = tx["merchant"].(map[string]any)["id"].(string)
	}

	// Cursor pagination: small pages add up to the full list, in order.
	all := orgPages(t, c, "/merchants?status=active", 100)
	paged := orgPages(t, c, "/merchants?status=active", 2)
	if len(all) != 5 || len(paged) != 5 {
		t.Fatalf("merchants: %d in one page, %d paged", len(all), len(paged))
	}
	for i := range all {
		if paged[i]["id"] != all[i]["id"] || paged[i]["version"] != 1.0 {
			t.Fatalf("paged order differs at %d: %v vs %v", i, paged[i], all[i])
		}
	}
	// Search keeps prefix matches first, also across pages.
	found := orgPages(t, c, "/merchants?q=am", 1)
	if len(found) != 4 || found[3]["name"] != "Kamal Stores" {
		t.Fatalf("search pages = %v", names(toAny(found), "name"))
	}
	first := names(toAny(found[:3]), "name")
	sort.Strings(first)
	if strings.Join(first, "|") != "AMZN Prime|Amazon|Amzn Mktp" {
		t.Fatalf("prefix matches = %v", first)
	}
	c.Do(t, http.MethodGet, "/merchants?cursor=not-a-cursor", nil).Expect(t, http.StatusUnprocessableEntity)
	c.Do(t, http.MethodGet, "/merchants?status=deleted", nil).Expect(t, http.StatusUnprocessableEntity)

	// PATCH checks version when sent; renaming onto another merchant's name is
	// 409 name_taken naming that merchant.
	amz, mktp, prime := mid["Amazon"], mid["Amzn Mktp"], mid["AMZN Prime"]
	up := c.Do(t, http.MethodPatch, "/merchants/"+amz, map[string]any{"website": "https://shop.example", "version": 1}).Expect(t, http.StatusOK).Data()
	if up["version"] != 2.0 || up["website"] != "https://shop.example" {
		t.Fatalf("versioned merchant patch = %v", up)
	}
	orgVersionConflict(t, c.Do(t, http.MethodPatch, "/merchants/"+amz, map[string]any{"notes": "stale", "version": 1}))
	params := orgCoded(t, c.Do(t, http.MethodPatch, "/merchants/"+mid["Kamal Stores"], map[string]any{"name": " zeta  store"}),
		http.StatusConflict, "CONFLICT", "name_taken")
	if params["merchant_id"] != mid["Zeta Store"] || params["name"] != "zeta  store" {
		t.Fatalf("name_taken params = %v", params)
	}
	if r := c.Do(t, http.MethodPatch, "/merchants/"+amz, map[string]any{"default_category_id": uuid.NewString()}); firstDetailField(r) != "body.default_category_id" {
		t.Fatalf("unknown default category: %s", r.Raw)
	}

	// Aliases can be removed again (matched like names).
	withAlias := c.Do(t, http.MethodPost, "/merchants/aliases", map[string]any{"merchant_id": amz, "alias": "AMZ Retail"}).Expect(t, http.StatusOK).Data()
	if !contains(toStrings(withAlias["aliases"]), "AMZ Retail") {
		t.Fatalf("alias not added: %v", withAlias["aliases"])
	}
	removed := c.Do(t, http.MethodPost, "/merchants/aliases/remove", map[string]any{"merchant_id": amz, "alias": " amz  retail "}).Expect(t, http.StatusOK).Data()
	if contains(toStrings(removed["aliases"]), "AMZ Retail") || removed["id"] != amz {
		t.Fatalf("alias not removed: %v", removed["aliases"])
	}
	c.Do(t, http.MethodPost, "/merchants/aliases/remove", map[string]any{"merchant_id": amz, "alias": "AMZ Retail"}).Expect(t, http.StatusNotFound)
	c.Do(t, http.MethodPost, "/merchants/aliases/remove", map[string]any{"merchant_id": uuid.NewString(), "alias": "AMZ Retail"}).Expect(t, http.StatusNotFound)
	if n := workerCount(t, s, `select count(*) from audit_events where entity_type = 'merchant' and entity_id = $1 and action = 'alias_removed'`, amz); n != 1 {
		t.Fatalf("alias removal audit events = %d", n)
	}

	// status: active by default, archived, merged or all.
	c.Do(t, http.MethodPatch, "/merchants/"+mid["Zeta Store"], map[string]any{"archived": true}).Expect(t, http.StatusOK)
	if got := orgNames(t, c, "/merchants"); len(got) != 4 || contains(got, "Zeta Store") {
		t.Fatalf("default list = %v", got)
	}
	if got := orgNames(t, c, "/merchants?status=archived"); len(got) != 1 || got[0] != "Zeta Store" {
		t.Fatalf("archived list = %v", got)
	}

	// References that a merge moves: transactions (a deleted one too),
	// aliases and names, a rule, a recurring rule, a subscription and a
	// budget allocation.
	extra := createTx(t, c, map[string]any{"type": "expense", "account_id": acct, "amount": "50", "merchant_name": "Amzn Mktp"})
	c.Do(t, http.MethodDelete, "/transactions/"+extra["id"].(string), nil).Expect(t, http.StatusOK)
	c.Do(t, http.MethodPost, "/merchants/aliases", map[string]any{"merchant_id": mktp, "alias": "AMZN MKTP IN*"}).Expect(t, http.StatusOK)
	rule := c.Do(t, http.MethodPost, "/category-rules", map[string]any{"name": "Marketplace", "match_field": "merchant", "match_type": "contains",
		"pattern": "mktp", "priority": 10, "set_category_id": categoryID(t, c, "Shopping")}).Expect(t, http.StatusCreated).Data()
	s.Env.ExecWorker(t, `update category_rules set set_merchant_id = $1 where id = $2`, mktp, rule["id"]) // not settable through the API
	today := todayIn(t, "Asia/Kolkata").Format(day)
	c.Do(t, http.MethodPost, "/recurring-rules", map[string]any{"kind": "expense", "name": "Marketplace plan", "frequency": "monthly",
		"start_date": today, "timezone": "Asia/Kolkata", "local_time": "09:00", "amount": "99", "account_id": acct, "merchant_name": "Amzn Mktp"},
		"Idempotency-Key", key()).Expect(t, http.StatusCreated)
	c.Do(t, http.MethodPost, "/subscriptions", map[string]any{"name": "Prime Video", "amount": "299", "billing_frequency": "monthly",
		"start_date": today, "merchant_name": "AMZN Prime"}, "Idempotency-Key", key()).Expect(t, http.StatusCreated)
	budget := c.Do(t, http.MethodPost, "/budgets", map[string]any{"name": "Monthly", "budget_type": "total", "period": "monthly", "currency": "INR",
		"limit": "10000"}, "Idempotency-Key", key()).Expect(t, http.StatusCreated).Data()
	s.Env.ExecWorker(t, `insert into budget_allocations (budget_id, merchant_id, limit_minor) values ($1, $2, 100000)`, budget["id"], prime)

	// The preview counts what moves and changes nothing.
	want := map[string]float64{"transactions": 3, "aliases": 3, "rules": 1, "recurring_rules": 1, "subscriptions": 1, "budget_allocations": 1,
		"budget_filters": 0}
	body := map[string]any{"source_ids": []string{mktp, prime, mktp}, "target_id": amz}
	orgAffected(t, c.Do(t, http.MethodPost, "/merchants/merge/preview", body).Expect(t, http.StatusOK).Data(), true, want)
	if g := c.Do(t, http.MethodGet, "/merchants/"+mktp, nil).Expect(t, http.StatusOK).Data(); g["status"] != "active" || g["merged_into_id"] != nil {
		t.Fatalf("preview changed the source: %v", g)
	}
	r := c.Do(t, http.MethodPost, "/merchants/merge/preview", map[string]any{"source_ids": []string{amz}, "target_id": amz})
	if r.ErrorCode() != "VALIDATION_ERROR" || firstDetailField(r) != "body.source_ids" {
		t.Fatalf("target among the sources: %s", r.Raw)
	}
	if r := c.Do(t, http.MethodPost, "/merchants/merge", map[string]any{"source_ids": []string{amz}, "target_id": amz}); r.ErrorCode() != "VALIDATION_ERROR" {
		t.Fatalf("merge into itself: %s", r.Raw)
	}
	c.Do(t, http.MethodPost, "/merchants/merge/preview", map[string]any{"source_ids": []string{uuid.NewString()}, "target_id": amz}).Expect(t, http.StatusNotFound)
	other, _ := s.Login(t, s.Register(t, "merchantthief"))
	other.Do(t, http.MethodPost, "/merchants/merge/preview", map[string]any{"source_ids": []string{mktp}, "target_id": amz}).Expect(t, http.StatusNotFound)
	other.Do(t, http.MethodPost, "/merchants/aliases/remove", map[string]any{"merchant_id": mktp, "alias": "AMZN MKTP IN*"}).Expect(t, http.StatusNotFound)

	// Merge: the target gains aliases and history; sources point to it.
	before := map[string]float64{}
	for _, src := range []string{mktp, prime} {
		before[src] = c.Do(t, http.MethodGet, "/merchants/"+src, nil).Expect(t, http.StatusOK).Data()["version"].(float64)
	}
	merged := c.Do(t, http.MethodPost, "/merchants/merge", body).Expect(t, http.StatusOK).Data()
	aliases := toStrings(merged["aliases"])
	if merged["id"] != amz || !contains(aliases, "AMZN MKTP IN*") || !contains(aliases, "Amzn Mktp") || !contains(aliases, "AMZN Prime") ||
		merged["transaction_count"] != 3.0 {
		t.Fatalf("merged target = %v", merged)
	}
	for _, src := range []string{mktp, prime} {
		g := c.Do(t, http.MethodGet, "/merchants/"+src, nil).Expect(t, http.StatusOK).Data()
		if g["status"] != "merged" || g["merged_into_id"] != amz || g["version"] != before[src]+1 {
			t.Fatalf("merged source = %v", g)
		}
	}
	mergedList := c.Do(t, http.MethodGet, "/merchants?status=merged", nil).Expect(t, http.StatusOK).List()
	if len(mergedList) != 2 || mergedList[0].(map[string]any)["merged_into_id"] != amz || mergedList[1].(map[string]any)["merged_into_id"] != amz {
		t.Fatalf("merged list = %v", mergedList)
	}
	if got := orgNames(t, c, "/merchants?status=all"); len(got) != 5 {
		t.Fatalf("all merchants = %v", got)
	}
	if n := workerCount(t, s, `select count(*) from category_rules where id = $1 and set_merchant_id = $2 and version = 2`, rule["id"], amz); n != 1 {
		t.Fatal("the rule did not move to the target")
	}
	if n := workerCount(t, s, `select count(*) from recurring_rules where merchant_id = $1`, amz); n != 1 {
		t.Fatal("the recurring rule did not move to the target")
	}
	if n := workerCount(t, s, `select count(*) from audit_events where entity_type = 'merchant' and entity_id = $1 and action = 'merged'
		and (changes->'affected'->>'transactions')::int = 3`, amz); n != 1 {
		t.Fatal("merge audit lacks the affected counts")
	}
	// Merged merchants cannot be merged again or edited.
	c.Do(t, http.MethodPost, "/merchants/merge/preview", map[string]any{"source_ids": []string{mktp}, "target_id": amz}).Expect(t, http.StatusNotFound)
	c.Do(t, http.MethodPatch, "/merchants/"+mktp, map[string]any{"notes": "x"}).Expect(t, http.StatusNotFound)
	c.Do(t, http.MethodPost, "/merchants/aliases/remove", map[string]any{"merchant_id": mktp, "alias": "Amzn Mktp"}).Expect(t, http.StatusNotFound)
}

func toAny(l []map[string]any) []any {
	out := make([]any, len(l))
	for i, x := range l {
		out[i] = x
	}
	return out
}

// The organize DTOs are typed in the generated contract, which the web and
// mobile clients generate their models from.
func TestOrganizeContractTypes(t *testing.T) {
	vals := map[string]string{
		"APP_ENV": "test", "DATABASE_URL": "postgres://unused/none", "DATA_ENCRYPTION_KEYS": "t1:KioqKioqKioqKioqKioqKioqKioqKioqKioqKioqKio=",
		"URL_SIGNING_KEY": "KioqKioqKioqKioqKioqKioqKioqKioqKioqKioqKio=", "EMAIL_PROVIDER": "dev_mailbox", "STORAGE_PROVIDER": "disabled",
	}
	cfg, err := config.LoadFrom(func(k string) (string, bool) { v, ok := vals[k]; return v, ok })
	if err != nil {
		t.Fatal(err)
	}
	deps := app.Deps{Cfg: cfg}
	svcs, err := app.NewServices(deps)
	if err != nil {
		t.Fatal(err)
	}
	_, api := app.NewRouter(deps, svcs)
	raw, err := json.Marshal(api.OpenAPI())
	if err != nil {
		t.Fatal(err)
	}
	var spec struct {
		Paths      map[string]map[string]map[string]any
		Components struct {
			Schemas map[string]struct {
				Properties map[string]map[string]any
				Required   []string
			}
		}
	}
	if err := json.Unmarshal(raw, &spec); err != nil {
		t.Fatal(err)
	}
	schema := func(name string) (map[string]map[string]any, []string) {
		t.Helper()
		s, ok := spec.Components.Schemas[name]
		if !ok {
			t.Fatalf("schema %s missing", name)
		}
		return s.Properties, s.Required
	}
	counts := func(name string, keys ...string) {
		t.Helper()
		props, req := schema(name)
		if len(props) != len(keys) {
			t.Fatalf("%s has %d properties, want %v", name, len(props), keys)
		}
		for _, k := range keys {
			if props[k]["type"] != "integer" || !contains(req, k) {
				t.Fatalf("%s.%s = %v (required %v)", name, k, props[k], req)
			}
		}
	}
	if p, _ := schema("MergeResult"); p["affected"]["$ref"] != "#/components/schemas/MergeAffected" {
		t.Fatalf("MergeResult.affected = %v", p["affected"])
	}
	counts("MergeAffected", "transactions", "subcategories", "rules", "budget_allocations", "recurring_rules", "bills", "subscriptions", "merchants",
		"budget_filters")
	if p, _ := schema("MerchantMergeResult"); p["affected"]["$ref"] != "#/components/schemas/MerchantMergeAffected" {
		t.Fatalf("MerchantMergeResult.affected = %v", p["affected"])
	}
	counts("MerchantMergeAffected", "transactions", "aliases", "rules", "recurring_rules", "subscriptions", "budget_allocations", "budget_filters")

	props, req := schema("RuleDTO")
	if typ, _ := props["currency"]["type"].([]any); len(typ) != 2 || !contains(req, "currency") || !contains(req, "version") {
		t.Fatalf("RuleDTO.currency = %v (required %v)", props["currency"], req)
	}
	for name, fields := range map[string][]string{"TagDTO": {"version"}, "MerchantDTO": {"version", "merged_into_id"},
		"MerchantDetail": {"version", "merged_into_id"}, "TagPatch": {"version", "clear_color"}, "CategoryPatch": {"clear_color"},
		"MerchantPatch": {"version"}, "RuleUpdate": {"version", "pattern"}, "RuleApplyInput": {"only_uncategorized"}} {
		p, _ := schema(name)
		for _, f := range fields {
			if p[f] == nil {
				t.Fatalf("%s.%s missing", name, f)
			}
		}
	}
	// Request schema names the clients already use stay stable.
	for _, name := range []string{"Merchants-mergeRequest", "TagBody", "RuleInput", "MergeInput"} {
		schema(name)
	}
	params := map[string]bool{}
	for _, p := range spec.Paths["/merchants"]["get"]["parameters"].([]any) {
		if n, ok := p.(map[string]any)["name"].(string); ok {
			params[n] = true
		}
	}
	if !params["status"] || !params["cursor"] || !params["limit"] || !params["q"] {
		t.Fatalf("GET /merchants parameters = %v", params)
	}
	for path, method := range map[string]string{"/categories/{id}": "get", "/category-rules/{id}/apply": "post", "/merchants/merge/preview": "post",
		"/merchants/aliases/remove": "post"} {
		if spec.Paths[path][method] == nil {
			t.Fatalf("%s %s missing", method, path)
		}
	}

	// The icon doc lists exactly the starter categories' icon names.
	var starter []string
	for _, c := range categories.StarterCategories {
		starter = append(starter, c.Icon)
	}
	sort.Strings(starter)
	for _, name := range []string{"CategoryInput", "CategoryPatch"} {
		p, _ := schema(name)
		doc, _ := p["icon"]["description"].(string)
		listed := strings.Split(doc[strings.LastIndex(doc, ": ")+2:], ", ")
		sort.Strings(listed)
		if strings.Join(listed, ",") != strings.Join(starter, ",") {
			t.Fatalf("%s.icon doc lists %v, starter icons are %v", name, listed, starter)
		}
	}
}
