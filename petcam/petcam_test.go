package main

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

// The pages that only need embedded templates must serve at the root mux.
// If the //go:embed paths or the mux wiring break, this fails.
func TestEmbeddedPages(t *testing.T) {
	h := PetcamMuxSetup()
	for _, p := range []string{"/live", "/label", "/review"} {
		rec := httptest.NewRecorder()
		h.ServeHTTP(rec, httptest.NewRequest(http.MethodGet, p, nil))
		if rec.Code != http.StatusOK {
			t.Fatalf("%s: got %d", p, rec.Code)
		}
		if !strings.Contains(strings.ToLower(rec.Body.String()), "<html") {
			t.Fatalf("%s: not an HTML page: %.80q", p, rec.Body.String())
		}
	}
}
