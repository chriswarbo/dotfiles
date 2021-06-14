#!/usr/bin/env python3
"""Watch data coming through a Kinesis stream. Sent over Slack from Jameel."""
import gzip
import base64
import argparse
from datetime import datetime
from kinesis.consumer import KinesisConsumer

parser = argparse.ArgumentParser()
parser.add_argument("streamid")
parser.add_argument("-topic")
parser.add_argument("-hidecontent")
parser.add_argument("-exact")
parser.add_argument("-decode")
parser.add_argument("-zipped")
args = parser.parse_args()
i = int(args.streamid)

streams = [
    {
        'stream' : 'Proj_Data_IngestionMaster-Dev',
        'encoded' : False
    },
    {
        'stream' : 'Proj_Data_KDBKinesis',
        'encoded' : False,
    },
    {
        'stream' : 'Proj_Data_IngestionMaster',
        'encoded' : False
    },
    {
        'stream' : 'Proj_NR_DARWIN',
        'encoded' : False
    },
     {
        'stream' : 'Proj_KDB_JourneyDemand',
        'encoded' : False
    },
     {
        'stream' : 'Proj_KDB_FeedInfo',
        'encoded' : False
    },
     {
        'stream' : 'Proj_KDB_Evo',
        'encoded' : False
    },
    {
        'stream' : 'Proj_Data_Analytics',
        'encoded': False
    }
]

stream = streams[i]['stream']
encoded = streams[i]['encoded']

print ("Listening to %s - encoded: %s" % (stream, str(encoded)))
print (args.topic)

consumer = KinesisConsumer(stream_name=stream)

for message in consumer:
    now = datetime.now()
    now_st = now.strftime("%d/%m/%Y %H:%M:%S")
    partition_key = message['PartitionKey']
    topic = partition_key.split('|')[-1]
    if args.topic and not args.topic in topic:
        continue

    if encoded or args.decode:
        data = message['Data']
        decoded = base64.b64decode(data)
        result = gzip.decompress(decoded)
    elif args.zipped:
        data = message['Data']
        unzipped = gzip.decompress(data)
        result = base64.b64decode(unzipped)
    else:
        result = message['Data']
    content = "" if args.hidecontent else result

    if args.topic:
        if not args.exact:
            if args.topic in topic:
                print("Partition Key %s" % partition_key)
                print("\033[1;32;40m[%s] [%s] Received message: \033[1;37;40m %s" % (now_st, topic, content))
        else:
             if args.topic == topic:
                print("Partition Key %s" % partition_key)
                print("\033[1;32;40m[%s] [%s] Received message: \033[1;37;40m %s" % (now_st, topic, content))
    else:
        print("\033[1;32;40m[%s] [%s] Received message: \033[1;37;40m %s" % (now_st, topic, content))
