package httpx

import (
	"bytes"
	"encoding/json"
	"testing"
)

type inner struct {
	Tags []string `json:"tags"`
}

type outer struct {
	Items   []inner         `json:"items"`
	Nested  *inner          `json:"nested"`
	Raw     json.RawMessage `json:"raw,omitempty"`
	Bytes   []byte          `json:"bytes,omitempty"`
	Missing []int           `json:"missing"`
	Any     any             `json:"any"`
}

func TestEmptyListsNeverEncodesNullLists(t *testing.T) {
	v := Envelope[outer]{Data: outer{Items: []inner{{}}, Nested: &inner{}, Any: inner{}}}
	var buf bytes.Buffer
	if err := jsonFormat.Marshal(&buf, v); err != nil {
		t.Fatal(err)
	}
	got := buf.String()
	for _, bad := range []string{`"tags":null`, `"missing":null`, `"items":null`} {
		if bytes.Contains(buf.Bytes(), []byte(bad)) {
			t.Fatalf("encoded a null list (%s): %s", bad, got)
		}
	}
	if bytes.Contains(buf.Bytes(), []byte(`"raw"`)) || bytes.Contains(buf.Bytes(), []byte(`"bytes"`)) {
		t.Fatalf("byte slices must be left alone: %s", got)
	}
	// Pointers are filled in place, values are copies; the input is not required to be addressable.
	if err := jsonFormat.Marshal(&buf, &v); err != nil {
		t.Fatal(err)
	}
}
