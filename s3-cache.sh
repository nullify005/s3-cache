#!/bin/bash

# what we are about
function usage() {
    cat << EOF
${0} -t <trigger_file> -a <action(pull|push)> -b <s3_bucket> -p <s3_prefix> -c <cache_path> -h <help>
where:
    t) the trigger file to use as the basis for whether the cache is invalid or not
    a) the action, pull or push
    b) the S3 bucket which we will push or pull from
    p) the prefix within the S3 bucket (for instance we could put our branch here)
    c) the path which we want to cache
    h) this message
AWS specific environment variables which need to be present for awscli / S3 access:
    AWS_ACCESS_KEY_ID
    AWS_SECRET_ACCESS_KEY
    AWS_DEFAULT_REGION
EOF
    exit 2
}

# generate an MD5 hash of the file & return it
function get_md5_hash {
    res=$(openssl md5 ${TRIGGER} | awk -F= '{print $2}' | sed "s/ //g")
    echo ${res}
}

# normalise & cleanup the cache path name for storage
function normalise_path {
    echo ${CACHE} | tr 'A-Z' 'a-z' | sed "s/\//_/g"
}

## generates an S3 URI
function gen_s3_uri {
    tgz=$(gen_tgz_name)
    echo "s3://${BUCKET}/${PREFIX}${tgz}"
}

# generates a tgz name
function gen_tgz_name {
    norm_path=$(normalise_path)
    trigger_md5=$(get_md5_hash)
    echo "${norm_path}-${trigger_md5}.tgz"
}

# checks to see whether the cache file might exist within S3 then pull & unpack it
function pull_s3_cache {
    tgz=$(gen_tgz_name)
    s3_uri=$(gen_s3_uri)
    aws s3 ls ${s3_uri} &> /dev/null
    if [ "${?}" ]; then
        echo "INFO: pulling ${s3_uri}"
        aws s3 cp ${s3_uri} . &&
        tar -xzf ${tgz}
        rm -f ${tgz}
    else
        echo "INFO: no cache file matches ${s3_uri}"
    fi
    return 0
}

# pushes the contents of cache to S3 for retrieval later on
function push_s3_cache {
    tgz=$(gen_tgz_name)
    s3_uri=$(gen_s3_uri)
    echo "INFO: packing and storing ${CACHE} to ${s3_uri}"
    tar -czf ${tgz} ${CACHE}
    aws s3 cp ${tgz} s3://${BUCKET}/${PREFIX}
    return ${?}
}

## process the opts
while getopts "t:a:b:p:c:h" opt; do
    case ${opt} in
        t) TRIGGER="${OPTARG}" ;;
        a) ACTION="${OPTARG}"  ;;
        b) BUCKET="${OPTARG}"  ;;
        p) PREFIX="${OPTARG}"  ;;
        c) CACHE="${OPTARG}"   ;;
        h) usage ;;
    esac
done

## validate the input
if [ ! -d "${CACHE}" ]; then echo "ERROR: invalid option, cache must be a path"; usage; fi
if [ -z "${ACTION}" ]; then echo "ERROR: no action specified, action must be either (pull|push)"; usage; fi
if [ -z "${BUCKET}" ]; then echo "ERROR: no S3 bucket has been specified"; usage; fi
if [ -z "${PREFIX}" ]; then PREFIX=""; fi
if [ ! -e "${TRIGGER}" ]; then echo "ERROR: no trigger file has been specified"; usage; fi
if [ ! "${AWS_ACCESS_KEY_ID}" ]; then echo "ERROR: no AWS key has been specified in the environment"; usage; fi
if [ ! "${AWS_SECRET_ACCESS_KEY}" ]; then echo "ERROR: no AWS secret has been specified in the environment"; usage; fi
if [ ! "${AWS_DEFAULT_REGION}" ]; then echo "ERROR: no AWS default region has been specified"; usage; fi
if [ ! `which aws` ]; then echo "ERROR: cannot locate aws cli on the PATH"; usage; fi
if [ ! `which openssl` ]; then echo "ERROR: cannot locate openssl on the PATH"; usage; fi

## main
RC=1
case "${ACTION}" in
    pull) pull_s3_cache; RC="${?}" ;;
    push) push_s3_cache; RC="${?}" ;;
    *) echo "ERROR: invalid action, must be one of (pull|push)"; usage ;;
esac
exit "${RC}"
