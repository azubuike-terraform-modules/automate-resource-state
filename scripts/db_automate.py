import boto3
import os
import sys
import time
import datetime
from time import gmtime, strftime
import logging

# available_regions = boto3.Session().get_available_regions('rds')
logger = logging.getLogger()
logger.setLevel("INFO")

def shut_rds_cluster():
    region=os.environ['REGION']
    key=os.environ['KEY']
    value=os.environ['VALUE']

    
    client = boto3.client('rds', region_name=region)
    response=client.describe_db_clusters()
    for cluster in response['DBClusters']:
        logger.info("Cluster info {}".format(cluster))
        cluarn=cluster['DBClusterArn']
        resp2=client.list_tags_for_resource(ResourceName=cluarn)
        logger.info('Tag list: {}'.format(resp2['TagList']))
        if len(resp2['TagList'])==0:
            logger.info('DB Cluster {0} is not part of autoshutdown'.format(cluster['DBClusterIdentifier']))
        else:
            for tag in resp2['TagList']:
                if tag['Key']==key and tag['Value']==value:
                    #check db cluster members and delete instance before deleting cluster
                    if len(cluster['DBClusterMembers']) !=0:
                        for member_db in cluster['DBClusterMembers']:
                            try:
                                response = client.delete_db_instance(
                                            DBInstanceIdentifier=member_db['DBInstanceIdentifier'],
                                            SkipFinalSnapshot=True
                                        )
                            except InvalidDBClusterStateFault:
                                logger.info('{} alreading in deleting state'.format(member_db['DBInstanceIdentifier']))
                            logger.info('{} instance database deleted'.format(member_db['DBInstanceIdentifier']))
                    if cluster['Status'] == 'available':
                        cluster_id = cluster['DBClusterIdentifier']
                        client.delete_db_cluster(DBClusterIdentifier=cluster['DBClusterIdentifier'],
                            FinalDBSnapshotIdentifier='{}-snapshot-{}'.format(cluster['DBClusterIdentifier'],datetime.datetime.now().strftime("%Y-%m-%d-%H-%M-%S")),
                            DeleteAutomatedBackups=True                        
                        )
                        logger.info('{} database cluster deleted'.format(cluster_id))
                else:
                    logger.info('DB Cluster {0} is not part of scheduled shutdown'.format(cluster['DBClusterIdentifier']))

def lambda_handler(event, context):
    shut_rds_cluster()