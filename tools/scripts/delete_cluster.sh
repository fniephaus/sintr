# Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE file.

# Delete cluster of sintr workers

function delete_cluster {
                    # $1 Worker base name
                    # $2 zone
                     WORKER_NAME_BASE=$1
                     ZONE=$2
                     NODE_COUNT_PER_ZONE=$3

                     echo "Deleting nodes in $2"

                     for i in `seq 1 $NODE_COUNT_PER_ZONE`;
                     do
                         WORKER_NAME=$WORKER_NAME_BASE$i
                         echo "Deleting " $WORKER_NAME
                         gcloud compute -q --project "liftoff-dev" \
                          instances delete $WORKER_NAME --zone $2 &
                     done
                     wait

                     echo "Nodes in $2 deleted"
                }

echo "Starting delete of " $1

delete_cluster "sintr-worker-usc1a-" "us-central1-a" $1
delete_cluster "sintr-worker-use1b-" "us-east1-b" $1
delete_cluster "sintr-worker-ase1a-" "asia-east1-a" $1
delete_cluster "sintr-worker-euw1b-" "europe-west1-b" $1

echo "Cluster delete completed"
