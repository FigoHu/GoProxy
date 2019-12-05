package main

import (
    "net/http"
    "log"
)

func main() {
    http.Handle("/", http.FileServer(http.Dir("/root/golang/www/")))
    err := http.ListenAndServe(":80", nil)
    if err != nil {
        log.Fatal("ListenAndServe: ", err)
    }
}