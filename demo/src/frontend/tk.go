package main

import (
	"context"

	"golang.org/x/oauth2"
	"google.golang.org/api/idtoken"
)

func VFToken(aud string, tk **oauth2.Token) string {
	if (*tk).Valid() {
		return (*tk).AccessToken
	} else {
		*tk = RetrieveToken(aud)
		return (*tk).AccessToken
	}
}

func RetrieveToken(aud string) *oauth2.Token {
	tokenSource, err := idtoken.NewTokenSource(context.Background(), aud)
	if err != nil {
		log.Errorf("idtoken.NewTokenSource: %v", err)
		return nil
	}
	token, err := tokenSource.Token()
	if err != nil {
		log.Errorf("TokenSource.Token: %v", err)
		return nil
	}

	// Add token to gRPC Request.
	// ctx = grpcMetadata.AppendToOutgoingContext(ctx, "authorization", "Bearer "+token.AccessToken)
	return token

}
