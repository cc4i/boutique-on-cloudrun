// Copyright 2018 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package main

import (
	"context"
	"crypto/tls"
	"crypto/x509"
	"fmt"
	"net/http"
	"os"
	"strings"
	"time"

	"cloud.google.com/go/profiler"
	"contrib.go.opencensus.io/exporter/jaeger"
	"contrib.go.opencensus.io/exporter/stackdriver"
	"github.com/gorilla/mux"
	"github.com/pkg/errors"
	"github.com/sirupsen/logrus"
	"go.opencensus.io/plugin/ocgrpc"
	"go.opencensus.io/plugin/ochttp"
	"go.opencensus.io/plugin/ochttp/propagation/b3"
	"go.opencensus.io/stats/view"
	"go.opencensus.io/trace"
	"google.golang.org/grpc"

	"golang.org/x/oauth2"
	"google.golang.org/grpc/credentials"
)

const (
	port            = "8080"
	defaultCurrency = "USD"
	cookieMaxAge    = 60 * 60 * 48

	cookiePrefix    = "shop_"
	cookieSessionID = cookiePrefix + "session-id"
	cookieCurrency  = cookiePrefix + "currency"
)

var (
	whitelistedCurrencies = map[string]bool{
		"USD": true,
		"EUR": true,
		"CAD": true,
		"JPY": true,
		"GBP": true,
		"TRY": true}
)

type ctxKeySessionID struct{}

type frontendServer struct {
	productCatalogSvcAddr string
	productCatalogSvcConn *grpc.ClientConn
	productCatalogToken   *oauth2.Token
	productCatalogAud     string

	currencySvcAddr  string
	currencySvcConn  *grpc.ClientConn
	currencySvcToken *oauth2.Token
	currencyAud      string

	cartSvcAddr  string
	cartSvcConn  *grpc.ClientConn
	cartSvcToken *oauth2.Token
	cartAud      string

	recommendationSvcAddr  string
	recommendationSvcConn  *grpc.ClientConn
	recommendationSvcToken *oauth2.Token
	recommendationAud      string

	checkoutSvcAddr  string
	checkoutSvcConn  *grpc.ClientConn
	checkoutSvcToken *oauth2.Token
	checkoutAud      string

	shippingSvcAddr  string
	shippingSvcConn  *grpc.ClientConn
	shippingSvcToken *oauth2.Token
	shippingAud      string

	adSvcAddr  string
	adSvcConn  *grpc.ClientConn
	adSvcToken *oauth2.Token
	adAud      string
}

func main() {
	ctx := context.Background()
	log := logrus.New()
	log.Level = logrus.DebugLevel
	log.Formatter = &logrus.JSONFormatter{
		FieldMap: logrus.FieldMap{
			logrus.FieldKeyTime:  "timestamp",
			logrus.FieldKeyLevel: "severity",
			logrus.FieldKeyMsg:   "message",
		},
		TimestampFormat: time.RFC3339Nano,
	}
	log.Out = os.Stdout

	if os.Getenv("DISABLE_TRACING") == "" {
		log.Info("Tracing enabled.")
		go initTracing(log)
	} else {
		log.Info("Tracing disabled.")
	}

	if os.Getenv("DISABLE_PROFILER") == "" {
		log.Info("Profiling enabled.")
		go initProfiling(log, "frontend", "1.0.0")
	} else {
		log.Info("Profiling disabled.")
	}

	srvPort := port
	if os.Getenv("PORT") != "" {
		srvPort = os.Getenv("PORT")
	}
	addr := os.Getenv("LISTEN_ADDR")
	svc := new(frontendServer)
	mustMapEnv(&svc.productCatalogSvcAddr, "PRODUCT_CATALOG_SERVICE_ADDR")
	mustMapEnv(&svc.currencySvcAddr, "CURRENCY_SERVICE_ADDR")
	mustMapEnv(&svc.cartSvcAddr, "CART_SERVICE_ADDR")
	mustMapEnv(&svc.recommendationSvcAddr, "RECOMMENDATION_SERVICE_ADDR")
	mustMapEnv(&svc.checkoutSvcAddr, "CHECKOUT_SERVICE_ADDR")
	mustMapEnv(&svc.shippingSvcAddr, "SHIPPING_SERVICE_ADDR")
	mustMapEnv(&svc.adSvcAddr, "AD_SERVICE_ADDR")

	mustConnGRPC(ctx, &svc.currencySvcConn, svc.currencySvcAddr, &svc.currencyAud, &svc.currencySvcToken)
	mustConnGRPC(ctx, &svc.productCatalogSvcConn, svc.productCatalogSvcAddr, &svc.productCatalogAud, &svc.productCatalogToken)
	mustConnGRPC(ctx, &svc.cartSvcConn, svc.cartSvcAddr, &svc.cartAud, &svc.cartSvcToken)
	mustConnGRPC(ctx, &svc.recommendationSvcConn, svc.recommendationSvcAddr, &svc.recommendationAud, &svc.recommendationSvcToken)
	mustConnGRPC(ctx, &svc.shippingSvcConn, svc.shippingSvcAddr, &svc.shippingAud, &svc.shippingSvcToken)
	mustConnGRPC(ctx, &svc.checkoutSvcConn, svc.checkoutSvcAddr, &svc.checkoutAud, &svc.checkoutSvcToken)
	mustConnGRPC(ctx, &svc.adSvcConn, svc.adSvcAddr, &svc.adAud, &svc.adSvcToken)

	r := mux.NewRouter()
	r.HandleFunc("/", svc.homeHandler).Methods(http.MethodGet, http.MethodHead)
	r.HandleFunc("/product/{id}", svc.productHandler).Methods(http.MethodGet, http.MethodHead)
	r.HandleFunc("/cart", svc.viewCartHandler).Methods(http.MethodGet, http.MethodHead)
	r.HandleFunc("/cart", svc.addToCartHandler).Methods(http.MethodPost)
	r.HandleFunc("/cart/empty", svc.emptyCartHandler).Methods(http.MethodPost)
	r.HandleFunc("/setCurrency", svc.setCurrencyHandler).Methods(http.MethodPost)
	r.HandleFunc("/logout", svc.logoutHandler).Methods(http.MethodGet)
	r.HandleFunc("/cart/checkout", svc.placeOrderHandler).Methods(http.MethodPost)
	r.PathPrefix("/static/").Handler(http.StripPrefix("/static/", http.FileServer(http.Dir("./static/"))))
	r.HandleFunc("/robots.txt", func(w http.ResponseWriter, _ *http.Request) { fmt.Fprint(w, "User-agent: *\nDisallow: /") })
	r.HandleFunc("/_healthz", func(w http.ResponseWriter, _ *http.Request) { fmt.Fprint(w, "ok") })

	var handler http.Handler = r
	handler = &logHandler{log: log, next: handler} // add logging
	handler = ensureSessionID(handler)             // add session ID
	handler = &ochttp.Handler{                     // add opencensus instrumentation
		Handler:     handler,
		Propagation: &b3.HTTPFormat{}}

	log.Infof("starting server on " + addr + ":" + srvPort)
	log.Fatal(http.ListenAndServe(addr+":"+srvPort, handler))
}

func initJaegerTracing(log logrus.FieldLogger) {

	svcAddr := os.Getenv("JAEGER_SERVICE_ADDR")
	if svcAddr == "" {
		log.Info("jaeger initialization disabled.")
		return
	}

	// Register the Jaeger exporter to be able to retrieve
	// the collected spans.
	exporter, err := jaeger.NewExporter(jaeger.Options{
		Endpoint: fmt.Sprintf("http://%s", svcAddr),
		Process: jaeger.Process{
			ServiceName: "frontend",
		},
	})
	if err != nil {
		log.Fatal(err)
	}
	trace.RegisterExporter(exporter)
	log.Info("jaeger initialization completed.")
}

func initStats(log logrus.FieldLogger, exporter *stackdriver.Exporter) {
	view.SetReportingPeriod(60 * time.Second)
	view.RegisterExporter(exporter)
	if err := view.Register(ochttp.DefaultServerViews...); err != nil {
		log.Warn("Error registering http default server views")
	} else {
		log.Info("Registered http default server views")
	}
	if err := view.Register(ocgrpc.DefaultClientViews...); err != nil {
		log.Warn("Error registering grpc default client views")
	} else {
		log.Info("Registered grpc default client views")
	}
}

func initStackdriverTracing(log logrus.FieldLogger) {
	// TODO(ahmetb) this method is duplicated in other microservices using Go
	// since they are not sharing packages.
	for i := 1; i <= 3; i++ {
		log = log.WithField("retry", i)
		exporter, err := stackdriver.NewExporter(stackdriver.Options{})
		if err != nil {
			// log.Warnf is used since there are multiple backends (stackdriver & jaeger)
			// to store the traces. In production setup most likely you would use only one backend.
			// In that case you should use log.Fatalf.
			log.Warnf("failed to initialize Stackdriver exporter: %+v", err)
		} else {
			trace.RegisterExporter(exporter)
			log.Info("registered Stackdriver tracing")

			// Register the views to collect server stats.
			initStats(log, exporter)
			return
		}
		d := time.Second * 20 * time.Duration(i)
		log.Debugf("sleeping %v to retry initializing Stackdriver exporter", d)
		time.Sleep(d)
	}
	log.Warn("could not initialize Stackdriver exporter after retrying, giving up")
}

func initTracing(log logrus.FieldLogger) {
	// This is a demo app with low QPS. trace.AlwaysSample() is used here
	// to make sure traces are available for observation and analysis.
	// In a production environment or high QPS setup please use
	// trace.ProbabilitySampler set at the desired probability.
	trace.ApplyConfig(trace.Config{DefaultSampler: trace.AlwaysSample()})

	initJaegerTracing(log)
	initStackdriverTracing(log)

}

func initProfiling(log logrus.FieldLogger, service, version string) {
	// TODO(ahmetb) this method is duplicated in other microservices using Go
	// since they are not sharing packages.
	for i := 1; i <= 3; i++ {
		log = log.WithField("retry", i)
		if err := profiler.Start(profiler.Config{
			Service:        service,
			ServiceVersion: version,
			// ProjectID must be set if not running on GCP.
			// ProjectID: "my-project",
		}); err != nil {
			log.Warnf("warn: failed to start profiler: %+v", err)
		} else {
			log.Info("started Stackdriver profiler")
			return
		}
		d := time.Second * 10 * time.Duration(i)
		log.Debugf("sleeping %v to retry initializing Stackdriver profiler", d)
		time.Sleep(d)
	}
	log.Warn("warning: could not initialize Stackdriver profiler after retrying, giving up")
}

func mustMapEnv(target *string, envKey string) {
	v := os.Getenv(envKey)
	if v == "" {
		panic(fmt.Sprintf("environment variable %q not set", envKey))
	}
	*target = v
}

// see: https://cloud.google.com/run/docs/triggering/grpc#configuring_your_service_to_use_http2
func mustConnGRPC(ctx context.Context, conn **grpc.ClientConn, addr string, aud *string, tok **oauth2.Token) {
	var err error
	ctx, cancel := context.WithTimeout(ctx, time.Second*3)
	defer cancel()

	///////
	// Extract audience
	*aud = "https://" + addr[:(strings.LastIndex(addr, ":"))] + "/"

	tkstr := VFToken(*aud, tok)
	log.Infof("token -> %s", tkstr)

	// Retrieve x509 cert
	systemRoots, err := x509.SystemCertPool()
	if err != nil {
		log.Errorf("x509.SystemCertPool: %v", err)
		return
	}
	cred := credentials.NewTLS(&tls.Config{
		RootCAs: systemRoots,
	})
	//
	//////
	*conn, err = grpc.DialContext(ctx, addr,
		grpc.WithAuthority(addr),
		grpc.WithTransportCredentials(cred),
		grpc.WithStatsHandler(&ocgrpc.ClientHandler{}))
	if err != nil {
		panic(errors.Wrapf(err, "grpc: failed to connect %s", addr))
	}

}
