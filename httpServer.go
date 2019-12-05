package main

import (
    "net/http"
    "fmt"
    "os"
    "github.com/spf13/viper"
    "log"
)

func main() {
    viper.SetConfigName("config")
    viper.AddConfigPath(".")
    viper.SetConfigType("json")
    err := viper.ReadInConfig()
    if err != nil {
        fmt.Printf("config file error: %s\n", err)
        os.Exit(1)
    }
    var wwwdir string
    var http_port string
    wwwdir = viper.Get("www_dir")
    http_port = viper.Get("http_port")
    http.Handle("/", http.FileServer(http.Dir(wwwdir)))
    err := http.ListenAndServe(":"+http_port, nil)
    if err != nil {
        log.Fatal("ListenAndServe: ", err)
    }
}