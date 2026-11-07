// petcam: standalone camera + gallery UI for Tom.
//
// Reached only through Ralph's nginx (proxy_pass to the tailnet address), which
// in turn is the Cloudflare tunnel origin. Nothing here does auth or TLS.
package main

import (
	"log"
	"net/http"
	"os"
	"time"
)

func main() {
	bind := os.Getenv("BIND") // empty => all interfaces; set it to the tailnet IP on Tom
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}
	addr := bind + ":" + port

	srv := &http.Server{
		Addr:           addr,
		Handler:        PetcamMuxSetup(),
		ReadTimeout:    10 * time.Second,
		WriteTimeout:   30 * time.Second,
		MaxHeaderBytes: 1 << 20,
	}
	log.Printf("listening on %s", addr)
	log.Fatal(srv.ListenAndServe())
}
