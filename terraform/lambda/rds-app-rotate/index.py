import json
import logging
import os
import ssl

import boto3
import pg8000.native as pg

log = logging.getLogger()
log.setLevel(os.environ.get("LOG_LEVEL", "INFO"))

sm = boto3.client("secretsmanager", endpoint_url=os.environ.get("SECRETS_MANAGER_ENDPOINT"))


def get_secret(secret_id, stage=None, version_id=None):
    kwargs = {"SecretId": secret_id}
    if version_id:
        kwargs["VersionId"] = version_id
    elif stage:
        kwargs["VersionStage"] = stage
    payload = sm.get_secret_value(**kwargs)
    log.info("loaded secret %s stage=%s version=%s", secret_id, stage, payload.get("VersionId"))
    return json.loads(payload["SecretString"])


def random_password():
    return sm.get_random_password(
        PasswordLength=32,
        ExcludeCharacters=":/@\"\\",
        ExcludePunctuation=True,
    )["RandomPassword"]


def app_secret(password):
    return {
        "engine": "postgres",
        "host": os.environ["DB_HOST"],
        "port": int(os.environ.get("DB_PORT") or 5432),
        "dbname": os.environ.get("DB_NAME") or "app",
        "username": os.environ.get("APP_USERNAME") or "app",
        "password": password,
    }


def connect(creds):
    ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_CLIENT)
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE
    try:
        conn = pg.Connection(
            user=creds["username"],
            password=creds["password"],
            host=creds["host"],
            port=int(creds.get("port") or 5432),
            database=creds.get("dbname") or "postgres",
            ssl_context=ctx,
            timeout=10,
        )
        log.info("db login ok user=%s host=%s", creds["username"], creds["host"])
        return conn
    except Exception:
        log.exception("db login failed user=%s host=%s", creds.get("username"), creds.get("host"))
        return None


def create_or_rotate_user(pending):
    if connect(pending):
        log.info("app user already accepts pending password")
        return
    log.info("creating/updating app user via master secret")
    master = get_secret(os.environ["MASTER_ARN"], stage="AWSCURRENT")
    as_master = dict(pending)
    as_master["username"] = master["username"]
    as_master["password"] = master["password"]
    conn = connect(as_master)
    if not conn:
        raise ValueError("cannot login as master")
    user = pending["username"]
    password = pending["password"]
    dbname = pending.get("dbname") or "app"
    ident = lambda name: conn.run("SELECT quote_ident(:n)", n=name)[0][0]
    quoted_user = ident(user)
    quoted_db = ident(dbname)
    quoted_pw = conn.run("SELECT quote_literal(:p)", p=password)[0][0]
    exists = conn.run("SELECT 1 FROM pg_roles WHERE rolname=:u", u=user)
    verb = "ALTER" if exists else "CREATE"
    log.info("%s ROLE %s", verb, user)
    conn.run("%s ROLE %s WITH LOGIN PASSWORD %s" % (verb, quoted_user, quoted_pw))
    conn.run("GRANT CONNECT ON DATABASE %s TO %s" % (quoted_db, quoted_user))
    conn.run("GRANT ALL ON SCHEMA public TO %s" % quoted_user)
    conn.close()
    log.info("app user %s is ready", user)


def pending_has_password(secret_id, token):
    try:
        pending = get_secret(secret_id, stage="AWSPENDING", version_id=token)
    except Exception:
        log.info("no AWSPENDING value for token %s", token)
        try:
            pending = get_secret(secret_id, version_id=token)
        except Exception:
            log.info("no secret value for token %s", token)
            return False
    has_password = bool(pending.get("password"))
    log.info("pending secret keys=%s password=%s", sorted(pending.keys()), has_password)
    return has_password


def handler(event, _context):
    secret_id = event.get("SecretId") or os.environ["APP_SECRET_ARN"]
    token = event["ClientRequestToken"]
    step = event["Step"]
    log.info("rotation step=%s secret=%s token=%s", step, secret_id, token)
    meta = sm.describe_secret(SecretId=secret_id)
    versions = meta.get("VersionIdsToStages") or {}
    stages = versions.get(token) or []
    log.info("token stages=%s", stages)

    if "AWSCURRENT" in stages:
        log.info("token already AWSCURRENT, skip")
        return

    if step == "createSecret":
        if pending_has_password(secret_id, token):
            log.info("pending password already exists")
            return
        sm.put_secret_value(
            SecretId=secret_id,
            ClientRequestToken=token,
            SecretString=json.dumps(app_secret(random_password())),
            VersionStages=["AWSPENDING"],
        )
        log.info("wrote AWSPENDING password")
        return

    if "AWSPENDING" not in stages:
        log.error("pending version is not staged")
        raise ValueError("pending version is not staged")

    if step == "setSecret":
        create_or_rotate_user(get_secret(secret_id, stage="AWSPENDING", version_id=token))
        log.info("setSecret done")
        return

    if step == "testSecret":
        if not connect(get_secret(secret_id, stage="AWSPENDING", version_id=token)):
            raise ValueError("app user login failed")
        log.info("testSecret ok")
        return

    if step == "finishSecret":
        current_id = None
        for version_id, st in versions.items():
            if "AWSCURRENT" in st:
                current_id = version_id
                break
        kwargs = {
            "SecretId": secret_id,
            "VersionStage": "AWSCURRENT",
            "MoveToVersionId": token,
        }
        if current_id and current_id != token:
            kwargs["RemoveFromVersionId"] = current_id
        log.info("promote pending to AWSCURRENT from=%s", current_id)
        sm.update_secret_version_stage(**kwargs)
        log.info("finishSecret done")
        return

    log.error("unknown step %s", step)
    raise ValueError("unknown step %s" % step)
