import json
import boto3

def lambda_handler(event, context):
    region = event.get( 'region' )

    efs_names = []
    efs = boto3.client('efs', region_name=region)
    cw = boto3.client('cloudwatch', region_name=region)

    efs_file_systems = efs.describe_file_systems()['FileSystems']

    for fs in efs_file_systems:
        efs_names.append(fs['Name'])
        cw.put_metric_data(
            Namespace="EFS Metrics",
            MetricData=[
                {
                    'MetricName': 'EFS Size',
                    'Dimensions': [
                        {
                            'Name': 'EFS_Name',
                            'Value': fs['Name']
                        }
                    ],
                    'Value': fs['SizeInBytes']['Value']/1024,
                    'Unit': 'Kilobytes'
                }
            ]
        )

    return efs_names
