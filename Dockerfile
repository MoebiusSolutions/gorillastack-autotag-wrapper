FROM ubuntu:latest

# NOTE: We apply some fixes to the code after checkout.
#       Review these when updating the version.
ARG AUTOTAG_VERSION=0.5.7

RUN set -x && \
    mkdir -p /opt/gorillastack-autotag-wrapper

# Add optional CA certs
# NOTE: The combination of a valid (meaningless) file ("cacerts.placeholder") and the "[m]" glob-pattern
#       means that the second file will only be copied if it exists. This is what we want.
ADD --chown=root:root cacerts.placeholder cacerts.pe[m] /opt/gorillastack-autotag-wrapper/

RUN set -x && \
    if [ -f /opt/gorillastack-autotag-wrapper/cacerts.pem ]; then \
        # Add the cacerts where they will be loaded by update-ca-certificates, when it is installed
        install -o root -g root -m 0755 -d /etc/ssl/; \
        install -o root -g root -m 0755 -d /etc/ssl/certs/; \
        cat /opt/gorillastack-autotag-wrapper/cacerts.pem >> /etc/ssl/certs/injected-cacerts.crt; \
    fi

RUN set -x && \
    #
    # Initialize apt
    apt-get -y update && \
    #
    # Install cert management tools
    apt-get -y install ca-certificates && \
    # ... and load any inject cacerts file
    update-ca-certificates && \
    #
    # Upgrade stale packages
    apt-get -y dist-upgrade && \
    #
    # Install helpers
    apt-get -y update && \
    apt-get -y install curl && \
    #
    # Install autotag dependencies
    DEBIAN_FRONTEND=noninteractive apt-get -y install jq npm git zip && \
    #
    # Manually install awscli in order to get v2
    curl -sf "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && \
    mkdir awscliv2 && \
    cd awscliv2 && \
    unzip -q "../awscliv2.zip" && \
    ./aws/install --bin-dir /usr/local/bin --install-dir /usr/local/aws-cli --update && \
    cd ../ && \
    rm -rf awscliv2 && \
    rm awscliv2.zip && \
    #
    # Cleanup APT
    rm -rf /var/lib/apt/lists/*

RUN set -x && \
    #
    # Checkout the code
    git clone --branch "$AUTOTAG_VERSION" https://github.com/GorillaStack/auto-tag.git /opt/auto-tag && \
    #
    # Update ARN refernece to automatically support "aws" or "aws-us-gov"
    sed -i 's/"Resource": "arn:aws:logs:\*:\*:\*"/"Resource": !Sub "arn:${AWS::Partition}:logs:*:*:*"/g' \
        /opt/auto-tag/cloud_formation/event_single_region_template/autotag_event-template.json && \
    #
    # Set ARN format to "aws-us-gov"
    # TODO: Make this dynamic
    sed -i 's/arn:aws:iam/arn:aws-us-gov:iam/g'  /opt/auto-tag/src/workers/autotag_default_worker.js && \
    #
    # Fix aparent bug in handling tagging of S3 buckets with zero initial tags
    # (See https://github.com/GorillaStack/auto-tag/issues/117)
    sed -i "s/err.code === 'NoSuchTagSet' && err.statusCode === 404/err.Code === 'NoSuchTagSet'/g" \
         /opt/auto-tag/src/workers/autotag_s3_worker.js

ADD build-and-deploy-code.sh /build-and-deploy-code.sh
RUN set -x && \
    chmod 0755 /build-and-deploy-code.sh


