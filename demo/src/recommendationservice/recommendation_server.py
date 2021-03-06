#!/usr/bin/python
#
# Copyright 2018 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

import os
import random
import time
import traceback
from concurrent import futures


from google.auth.exceptions import DefaultCredentialsError
import grpc

import google.oauth2.id_token
import google.auth.transport.requests
import google.auth.transport.grpc
# import google.auth.credentials.Credentials
# from google.auth.transport import grpc as google_auth_transport_grpc

import demo_pb2
import demo_pb2_grpc
from grpc_health.v1 import health_pb2
from grpc_health.v1 import health_pb2_grpc

from logger import getJSONLogger
logger = getJSONLogger('recommendationservice-server')

def check_and_refresh():
    ####
    # Method 2
    global credentials
    global product_catalog_stub
    if credentials.expired:
      request1 = google.auth.transport.requests.Request()
      target_audience1 = "https://{}/".format(catalog_addr.partition(":")[0])
      credentials = google.oauth2.id_token.fetch_id_token_credentials(target_audience1, request=request1)
      credentials.refresh(request1)
      id_token1 = credentials.token

      tok1 = grpc.access_token_call_credentials(id_token1)
      ccc1 = grpc.composite_channel_credentials(grpc.ssl_channel_credentials(), tok1)
      channel1 = grpc.secure_channel(catalog_addr,ccc1)
      product_catalog_stub = demo_pb2_grpc.ProductCatalogServiceStub(channel1)
    ####
    
class RecommendationService(demo_pb2_grpc.RecommendationServiceServicer):
    def ListRecommendations(self, request, context):
      try:
        logger.info("Entered into ListRecommendations()") 
        max_responses = 5
        # Check token is expired or not
        check_and_refresh()
        # fetch list of products from product catalog stub
        cat_response = product_catalog_stub.ListProducts(demo_pb2.Empty())
        product_ids = [x.id for x in cat_response.products]
        filtered_products = list(set(product_ids)-set(request.product_ids))
        num_products = len(filtered_products)
        num_return = min(max_responses, num_products)
        # sample list of indicies to return
        indices = random.sample(range(num_products), num_return)
        # fetch product ids from indices
        prod_list = [filtered_products[i] for i in indices]
        logger.info("[Recv ListRecommendations] product_ids={}".format(prod_list))
        # build and return response
        response = demo_pb2.ListRecommendationsResponse()
        response.product_ids.extend(prod_list)
        logger.info("Exited into ListRecommendations()") 
      except Exception as e:
        logger.error("ListRecommendations error={}".format(e)) 
        return []
      return response
      

    def Check(self, request, context):
        return health_pb2.HealthCheckResponse(
            status=health_pb2.HealthCheckResponse.SERVING)

    def Watch(self, request, context):
        return health_pb2.HealthCheckResponse(
            status=health_pb2.HealthCheckResponse.UNIMPLEMENTED)


if __name__ == "__main__":
    logger.info("initializing recommendationservice")

    port = os.environ.get('PORT', "8080")
    catalog_addr = os.environ.get('PRODUCT_CATALOG_SERVICE_ADDR', '')
    if catalog_addr == "":
        raise Exception('PRODUCT_CATALOG_SERVICE_ADDR environment variable not set')
    logger.info("product catalog address: " + catalog_addr)
    
    # ######
    # # Method 1 !!!Changes!!!
    # credentials, _ = google.auth.default()
    # request = google.auth.transport.requests.Request()
    # target_audience = "https://{}/".format(catalog_addr.partition(":")[0])
    # id_token = google.oauth2.id_token.fetch_id_token(request, target_audience)
    # # req.add_header("Authorization", f"Bearer {id_token}")
    # tok = grpc.access_token_call_credentials(id_token)
    # ccc = grpc.composite_channel_credentials(grpc.ssl_channel_credentials(), tok)

    # channel = grpc.secure_channel(catalog_addr,ccc)

    # product_catalog_stub = demo_pb2_grpc.ProductCatalogServiceStub(channel)
    # #####

    ####
    # Method 2
    request = google.auth.transport.requests.Request()
    target_audience = "https://{}/".format(catalog_addr.partition(":")[0])
    credentials = google.oauth2.id_token.fetch_id_token_credentials(target_audience, request=request)
    credentials.refresh(request)
    id_token = credentials.token

    tok = grpc.access_token_call_credentials(id_token)
    ccc = grpc.composite_channel_credentials(grpc.ssl_channel_credentials(), tok)
    channel = grpc.secure_channel(catalog_addr,ccc)
    product_catalog_stub = demo_pb2_grpc.ProductCatalogServiceStub(channel)
    ####

    # create gRPC server
    server = grpc.server(futures.ThreadPoolExecutor(max_workers=10))

    # add class to gRPC server
    service = RecommendationService()
    demo_pb2_grpc.add_RecommendationServiceServicer_to_server(service, server)
    health_pb2_grpc.add_HealthServicer_to_server(service, server)

    # start server
    logger.info("listening on port: " + port)
    server.add_insecure_port('[::]:'+port)
    server.start()

    # keep alive
    try:
         while True:
            time.sleep(10000)
    except KeyboardInterrupt:
            server.stop(0)

