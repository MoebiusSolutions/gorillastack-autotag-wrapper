gorillastack-autotag-wrapper
================

Overview
----------------

This repo wraps GorrilaStack's [auto-tag](https://github.com/GorillaStack/auto-tag/)
solution for automatically tagging AWS resources.

I created this repo for a few reasons:

1. GorrilaStack's solution does not support the GovCloud regions out of the box,
   so this repo solidifies some code workarounds

2. I didn't love GorrilaStack's StackSet architecture

    1. We only run in one region, so we don't need the added complexity

    2. I was a little hesitant to hand over admin privileges to their code
       (required per the GorillaStack instructions for using the StackSet)

    3. I hit some confusing errors while trying to deploy the StackSet,
       but I suspect those may be resolved by the code changes I've since applied in
       my `Dockerfile`

3. I do not need GorrilaStack's code making changes to my workstation
   (they blindly run `apt install` on my host in `deploy_autotag.sh`),
   so I pushed everything into a Docker image

4. Our environment requires a custom cacert for all egress,
   so I built in optional support for this certificate during image build

Comparison of this approach to GorillaStack's 
[CloudFormation StackSet Deployment Method](https://github.com/GorillaStack/auto-tag/blob/master/STACKSET.md)

At the end of the day, GorillaStack's instructions use these:

* [GorillaStack `event_multi_region_template` templates](https://github.com/GorillaStack/auto-tag/tree/master/cloud_formation/event_multi_region_template)

... and my approach uses these:

* [GorillaStack `autotag_event-template.json` template](https://github.com/GorillaStack/auto-tag/blob/master/cloud_formation/event_single_region_template/autotag_event-template.json):
  A "single region" CloudFormation template from GorillaStack that appears to be undocumented
* [Our `build-and-deploy-code.sh`](build-and-deploy-code.sh):
  A very stripped-down script that uploads the `autotag.zip` code bundle


Prerequisites
----------------

**Docker or Podman**: You'll need docker or Podman installed to build/run the container.
(but none of the other tools that GorillaStack's scripts require).

**AWS CLI Config**: We happen to configure our AWS region and AWS credentials in our
`~/.aws/` (on our workstation),
which reduces the number of things that need to be passed down to the scripts.
You may want to replicate this.

**S3 Bucket**: You'll need to create an S3 bucket in your region that can be used to
store the NodeJS code run by the Lambda function.


Setup
----------------

Checkout the code:

    git clone https://github.com/MoebiusSolutions/gorillastack-autotag-wrapper.git
    cd gorillastack-autotag-wrapper/

(Optional) Create the following file if you need additional CACerts loaded when building the docker image.

    cacerts.pem


Deploy
----------------

**NOTE**: `./build-docker.sh` and `./run-docker.sh` are very much suggestions.
You will likely adjust to your needs--adding additional arguments,
changing from `podman` to `docker`, etc.

Build the docker image (via Podman):

    ./build-docker.sh

... which generates this image:

    gorillastack-autotag-wrapper:local-build

Run the docker image (via Podman):

    ./run-docker.sh

... which:

* Mounts your `~/.aws` (and any credentials) into the container
* Drops you into a bash terminal inside the image

From inside the container, you can build/deploy the auto-run NodeJS code to your S3 bucket:

    /opt/gorillastack-autotag-wrapper/build-and-deploy-code.sh <s3-bucket-name> <s3-file-path>

... for example:

    /opt/gorillastack-autotag-wrapper/build-and-deploy-code.sh my-autotag-bucket autotag.zip

From inside the container, you can deploy the CloudFormation template with:

    aws cloudformation deploy \
      --template-file /opt/auto-tag/cloud_formation/event_single_region_template/autotag_event-template.json \
      --stack-name ... \
      --capabilities CAPABILITY_IAM
      --parameter-overrides \
        ... \

... for example:

    aws cloudformation deploy \
      --template-file /opt/auto-tag/cloud_formation/event_single_region_template/autotag_event-template.json \
      --stack-name "my-autotag-stack" \
      --capabilities CAPABILITY_IAM \
      --parameter-overrides \
        "LambdaName=AutoTag" \
        "CodeS3Bucket=my-autotag-bucket" \
        "CodeS3Path=autotag.zip" \
        "AutoTagDebugLogging=Enabled" \
        "AutoTagDebugLoggingOnFailure=Enabled" \
        "AutoTagTagsCreateTime=Enabled" \
        "AutoTagTagsInvokedBy=Enabled" \
        "LogRetentionInDays=90" \
        "CustomTags="

At this point you should have a CloudFormation stack deployed that contains
a Lambda function that runs every time a supported resource is created.
