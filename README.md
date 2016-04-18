## S3 Cache

A reimplementation of the Travis ruby bundle cache mechanism but not specific to
ruby itself

The intent is to use this script to reduce build times of EC2 images which
have ruby applications deployed within them by reusing the bundle install
output

```
./s3-cache.sh -t <trigger_file> -a <action(pull|push)> -b <s3_bucket> -p <s3_prefix> -c <cache_path> -h <help>
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
```
