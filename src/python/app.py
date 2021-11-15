# ------------------------------------------------------------
# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.
# ------------------------------------------------------------

import os
import requests
import time

dapr_port = os.getenv("DAPR_HTTP_PORT", 3500)
dapr_url = "http://localhost:{}/v1.0/invoke/nodeapp/method/neworder".format(dapr_port)

n = 0

# for loop with fibonacci sequence
for i in range(1, 1000):
    n = n + i
    print("Invoking neworder() with n = {}".format(n))
    response = requests.post(dapr_url, json={"new order with id ": n})
    print("Response: {}".format(response.text))
    time.sleep(1)

