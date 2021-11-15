# ------------------------------------------------------------
# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.
# ------------------------------------------------------------

import os
import requests
import time

dapr_port = os.getenv("DAPR_HTTP_PORT", 3500)
dapr_url = "http://localhost:{}/v1.0/invoke/nodeapp/method/neworder".format(dapr_port)

# calculate next prime number in while loop
n = 1
while True:
    n = n + 1
    is_prime = True
    for i in range(2, n):
        if n % i == 0:
            is_prime = False
            break
    if is_prime:
        print("Invoking neworder() with n = {}".format(n))
        response = requests.post(dapr_url, json={"data": {"orderId": n}})
        print("Response: {}".format(response.text))
        time.sleep(1)