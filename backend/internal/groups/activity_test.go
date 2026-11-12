package groups

import (
	"go/ast"
	"go/parser"
	"go/token"
	"os"
	"reflect"
	"slices"
	"strings"
	"testing"
)

// The activity contract (GroupActivityDTO.kind and GroupActivitySummary)
// must list exactly what this package writes: every kind passed to
// activity(), every summary key, and nothing else.
func TestActivityContractMatchesCode(t *testing.T) {
	fset := token.NewFileSet()
	entries, err := os.ReadDir(".")
	if err != nil {
		t.Fatal(err)
	}
	var files []*ast.File
	for _, e := range entries {
		if e.IsDir() || !strings.HasSuffix(e.Name(), ".go") || strings.HasSuffix(e.Name(), "_test.go") {
			continue
		}
		f, err := parser.ParseFile(fset, e.Name(), nil, 0)
		if err != nil {
			t.Fatal(err)
		}
		files = append(files, f)
	}
	written := map[string]bool{}
	keys := map[string]bool{}
	mapKeys := func(e ast.Expr) {
		if m, ok := e.(*ast.CompositeLit); ok {
			for _, el := range m.Elts {
				if kv, ok := el.(*ast.KeyValueExpr); ok {
					if lit, ok := kv.Key.(*ast.BasicLit); ok && lit.Kind == token.STRING {
						keys[strings.Trim(lit.Value, `"`)] = true
					}
				}
			}
		}
	}
	isSummary := func(e ast.Expr) bool {
		id, ok := e.(*ast.Ident)
		return ok && id.Name == "summary"
	}
	for _, f := range files {
		ast.Inspect(f, func(n ast.Node) bool {
			switch x := n.(type) {
			case *ast.CallExpr:
				// activity(ctx, tx, groupID, actor, kind, entityType, entityID, summary)
				if id, ok := x.Fun.(*ast.Ident); ok && id.Name == "activity" && len(x.Args) == 8 {
					if lit, ok := x.Args[4].(*ast.BasicLit); ok && lit.Kind == token.STRING {
						written[strings.Trim(lit.Value, `"`)] = true
					}
					mapKeys(x.Args[7])
				}
			case *ast.AssignStmt:
				// summary := map[string]any{...} and summary["key"] = ...
				for i, l := range x.Lhs {
					if isSummary(l) && i < len(x.Rhs) {
						mapKeys(x.Rhs[i])
					}
					if ix, ok := l.(*ast.IndexExpr); ok && isSummary(ix.X) {
						if lit, ok := ix.Index.(*ast.BasicLit); ok && lit.Kind == token.STRING {
							keys[strings.Trim(lit.Value, `"`)] = true
						}
					}
				}
			}
			return true
		})
	}
	// Kinds built at run time (SetStatus, ResolveDispute, insertSettlement
	// and SetRecurringStatus), plus everything the worker notifies about.
	for _, k := range []string{"group_archived", "group_restored", "group_deleted", "dispute_resolved", "dispute_withdrawn",
		"settlement_proposed", "settlement_reported", "settlement_confirmed", "recurring_expense_paused", "recurring_expense_resumed",
		"recurring_expense_stopped"} {
		written[k] = true
	}
	for k := range notices {
		written[k] = true
	}
	tag := func(field string) string {
		f, ok := reflect.TypeOf(GroupActivityDTO{}).FieldByName(field)
		if !ok {
			t.Fatalf("GroupActivityDTO.%s missing", field)
		}
		return f.Tag.Get("enum")
	}
	kinds := strings.Split(tag("Kind"), ",")
	for k := range written {
		if !slices.Contains(kinds, k) {
			t.Errorf("activity kind %q is written but not in GroupActivityDTO.kind", k)
		}
	}
	for _, k := range kinds {
		if !written[k] {
			t.Errorf("GroupActivityDTO.kind lists %q, which nothing writes", k)
		}
	}
	if len(kinds) != len(written) {
		t.Errorf("%d kinds in the enum, %d written", len(kinds), len(written))
	}
	var tags []string
	st := reflect.TypeOf(GroupActivitySummary{})
	for i := 0; i < st.NumField(); i++ {
		tags = append(tags, strings.Split(st.Field(i).Tag.Get("json"), ",")[0])
	}
	for k := range keys {
		if !slices.Contains(tags, k) {
			t.Errorf("summary key %q is written but not a GroupActivitySummary field", k)
		}
	}
	for _, k := range tags {
		if !keys[k] {
			t.Errorf("GroupActivitySummary.%s is never written", k)
		}
	}
}
