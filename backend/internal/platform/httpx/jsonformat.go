package httpx

import (
	"encoding/json"
	"io"
	"reflect"

	"github.com/danielgtaylor/huma/v2"
)

// jsonFormat encodes responses with every nil slice as [] (the contract
// declares lists non-nullable, and clients must never see `null` lists).
// []byte and json.RawMessage are left alone.
var jsonFormat = huma.Format{
	Marshal: func(w io.Writer, v any) error {
		return json.NewEncoder(w).Encode(EmptyLists(v))
	},
	Unmarshal: json.Unmarshal,
}

// EmptyLists returns v with nil slices (at any depth) replaced by empty
// slices. Pointers are followed and filled in place; values are copied.
func EmptyLists(v any) any {
	if v == nil {
		return nil
	}
	rv := reflect.ValueOf(v)
	if rv.Kind() != reflect.Pointer {
		cp := reflect.New(rv.Type()).Elem()
		cp.Set(rv)
		fill(cp, 0)
		return cp.Interface()
	}
	fill(rv, 0)
	return v
}

var byteSlice = reflect.TypeOf([]byte(nil))

func fill(v reflect.Value, depth int) {
	if depth > 32 || !v.IsValid() {
		return
	}
	switch v.Kind() {
	case reflect.Pointer, reflect.Interface:
		if !v.IsNil() {
			e := v.Elem()
			if v.Kind() == reflect.Interface && e.Kind() != reflect.Pointer {
				// A value inside an interface is not addressable: copy, fill, store back.
				if v.CanSet() && needsFill(e.Type()) {
					cp := reflect.New(e.Type()).Elem()
					cp.Set(e)
					fill(cp, depth+1)
					v.Set(cp)
				}
				return
			}
			fill(e, depth+1)
		}
	case reflect.Struct:
		for i := 0; i < v.NumField(); i++ {
			if f := v.Field(i); f.CanSet() || f.Kind() == reflect.Pointer || f.Kind() == reflect.Slice {
				fill(f, depth+1)
			}
		}
	case reflect.Slice:
		if v.Type().Elem().Kind() == reflect.Uint8 || v.Type().ConvertibleTo(byteSlice) {
			return
		}
		if v.IsNil() {
			if v.CanSet() {
				v.Set(reflect.MakeSlice(v.Type(), 0, 0))
			}
			return
		}
		for i := 0; i < v.Len(); i++ {
			fill(v.Index(i), depth+1)
		}
	case reflect.Map:
		// Map values are not addressable; lists inside maps are rare in DTOs.
	}
}

// needsFill reports whether a type can contain slices.
func needsFill(t reflect.Type) bool {
	switch t.Kind() {
	case reflect.Slice, reflect.Struct, reflect.Pointer, reflect.Interface:
		return true
	}
	return false
}
