import boto3
import os
import sys
import time
from datetime import datetime, timezone
from time import gmtime, strftime
import logging

# available_regions = boto3.Session().get_available_regions('rds')

def shut_rds_cluster():
    region=os.environ['REGION']
    key=os.environ['KEY']
    value=os.environ['VALUE']

    
    client = boto3.client('rds', region_name=region)
    response=client.describe_db_clusters()
    for cluster in response['DBClusters']:
        cluarn=cluster['DBClusterArn']
        resp2=client.list_tags_for_resource(ResourceName=cluarn)
        if 0==len(resp2['TagList']):
            logging.info('DB Cluster {0} is not part of autoshutdown'.format(cluster['DBClusterIdentifier']))
        else:
            for tag in resp2['TagList']:
                if tag['Key']==key and tag['Value']==value:
                    #check db cluster members and delete instance before deleting cluster
                    for member_db in cluster['DBClusterMembers']:
                        response = client.delete_db_instance(
                                    DBInstanceIdentifier=member_db['DBInstanceIdentifier'],
                                    SkipFinalSnapshot=True
                                )
                    if cluster['Status'] == 'available':
                        client.delete_db_cluster(DBClusterIdentifier=cluster['DBClusterIdentifier'],
                            FinalDBSnapshotIdentifier='{}-snapshot-{}'.format(cluster['DBClusterIdentifier'],datetime.date()),
                            DeleteAutomatedBackups=True                        
                        )
                elif tag['Key'] != key and tag['Value'] != value:
                    logging.info('DB Cluster {0} is not part of autoshutdown'.format(cluster['DBClusterIdentifier']))
                else:
                    logging.info('DB Instance {0} is not part of auroShutdown'.format(cluster['DBClusterIdentifier']))

def lambda_handler(event, context):
    shut_rds_cluster()