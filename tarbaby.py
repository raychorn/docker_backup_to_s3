import os
import sys
import json
import time
import docker
import psutil

import socket

import types
import dotenv

import traceback

from expandvars import expandvars

import pymongo
from pymongo import ReturnDocument
from pymongo.mongo_client import MongoClient

is_really_something = lambda s,t:(s is not None) and ( (callable(t) and (not isinstance(t, types.FunctionType)) and isinstance(s, t)) or (callable(t) and (isinstance(t, types.FunctionType)) and t(s)) )
is_really_something_with_stuff = lambda s,t:is_really_something(s,t) and (len(s) > 0)

is_not_none = lambda s:(s is not None)

db = lambda cl,n:cl.get_database(n)
db_collection = lambda cl,n,c:db(cl,n).get_collection(c)

db_coll = lambda cl,n,c:cl.get_database(n).get_collection(c)

try:
    fp_env = dotenv.find_dotenv()
    if (os.path.exists(fp_env)):
        print('fp_env: {}'.format(fp_env))
        dotenv.load_dotenv(fp_env)
    else:
        print('Cannot find "{}" so using the OS Environ instead.'.format(fp_env))
except:
    pass

def get_mongo_client(mongouri=None, db_name=None, username=None, password=None, authMechanism=None):
    if (is_not_none(authMechanism)):
        assert is_not_none(username), 'Cannot continue without a username ({}).'.format(username)
        assert is_not_none(password), 'Cannot continue without a password ({}).'.format(password)
    assert is_not_none(db_name), 'Cannot continue without a db_name ({}).'.format(db_name)
    assert is_not_none(mongouri), 'Cannot continue without a mongouri ({}).'.format(mongouri)
    return  MongoClient(mongouri, username=username, password=password, authSource=db_name, authMechanism=authMechanism)

__env__ = {}
__literals__ = os.environ.get('LITERALS', [])
__literals__ = [__literals__] if (not isinstance(__literals__, list)) else __literals__
for k,v in os.environ.items():
    if (k.find('MONGO_') > -1):
        __env__[k] = expandvars(v) if (k not in __literals__) else v

__env__['MONGO_INITDB_DATABASE'] = os.environ.get('MONGO_INITDB_DATABASE')
__env__['MONGO_URI'] = os.environ.get('MONGO_URI')
__env__['MONGO_INITDB_USERNAME'] = os.environ.get("MONGO_INITDB_ROOT_USERNAME")
__env__['MONGO_INITDB_PASSWORD'] = os.environ.get("MONGO_INITDB_ROOT_PASSWORD")
__env__['MONGO_AUTH_MECHANISM'] = os.environ.get('MONGO_AUTH_MECHANISM')

try:
    client = get_mongo_client(mongouri=__env__.get('MONGO_URI'), db_name=__env__.get('MONGO_INITDB_DATABASE'), username=__env__.get('MONGO_INITDB_USERNAME'), password=__env__.get('MONGO_INITDB_PASSWORD'), authMechanism=__env__.get('MONGO_AUTH_MECHANISM'))
except Exception as ex:
    print('ERROR: Could not connect to MongoDB.')
    traceback.print_exc()
    sys.exit()
    
print('client: {}'.format(client))

dest_db_name = os.environ.get('MONGO_DEST_DATA_DB')

source_dir = os.environ.get('SRC_DIR')

dest_dir = os.environ.get('DEST_DIR')

wait_secs = int(os.environ.get('WAIT_SECS', '86400'))

try:
    assert is_really_something_with_stuff(dest_db_name, str), 'Cannot continue without the dest db_name.'
except Exception as ex:
    print("Fatal error with .env, check MONGO_DEST_DATA_DB.")
    traceback.print_exc()
    sys.exit()


if (len(sys.argv) > 1 and isinstance(sys.argv[1], str) and (len(sys.argv[1]) > 0)):
    _hostname = sys.argv[1]
else:
    _hostname = os.environ.get('HOST_HOSTNAME', socket.gethostname())

dest_coll = db_collection(client, dest_db_name, _hostname)
print('dest_coll: {}'.format(dest_coll.full_name))

print('-'*80)

import tarfile

if (os.path.exists(source_dir) and os.path.isdir(source_dir)):
    print('source_dir: {}'.format(source_dir))
    if (os.path.exists(dest_dir) and os.path.isdir(dest_dir)):
        print('dest_dir: {}'.format(dest_dir))
        try:
            while (1):
                files_count = 0
                for root, dirs, files in os.walk(source_dir):
                    for f in files:
                        files_count += 1
                print('files_count: {}'.format(files_count))
                current_files_count = 0
                tarFile = tarfile.open("{}{}{}.tar.gz".format(dest_dir, os.sep, '_'.join(source_dir.split(os.sep)[1:])), "w:gz")
                for root, dirs, files in os.walk(source_dir):
                    for f in files:
                        fpath = os.path.join(root, f)
                        tarFile.add(fpath)
                        current_files_count += 1
                        cpcent = float(current_files_count / files_count * 100.0)
                        print('{} of {} --> {:.2f}'.format(current_files_count, files_count, cpcent))
                tarFile.close()
                time.sleep(wait_secs)
        finally:
            print('Done.')
else:
    print('ERROR: Cannot find "{}" so cannot continue.'.format(source_dir))
    sys.exit()
    
print('Done.')
        