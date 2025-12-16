from mcp.server.fastmcp import FastMCP
import boto3
import json
from datetime import datetime
from typing import Dict, List, Any, Optional

# Initialize the MCP Server
mcp = FastMCP("AWS Resource Inspector")

class AWSResourceManager:
    """
    Handles AWS resource interactions with proper error handling 
    and response formatting.
    """
    def __init__(self):
        self._clients: Dict[str, Any] = {}

    def get_client(self, service_name: str, region_name: str = "us-east-1"):
        """Lazy loading of AWS clients to improve startup time"""
        cache_key = f"{service_name}_{region_name}"
        if cache_key not in self._clients:
            self._clients[cache_key] = boto3.client(service_name, region_name=region_name)
        return self._clients[cache_key]

    def _format_date(self, obj: Any) -> str:
        """Helper to safely format datetime objects"""
        if isinstance(obj, datetime):
            return obj.isoformat()
        return str(obj)

    def list_s3_buckets(self) -> str:
        try:
            s3 = self.get_client('s3')
            response = s3.list_buckets()
            buckets = [
                {
                    "Name": b['Name'],
                    "CreationDate": self._format_date(b['CreationDate'])
                }
                for b in response.get('Buckets', [])
            ]
            return json.dumps(buckets, indent=2)
        except Exception as e:
            return f"Error listing buckets: {str(e)}"

    def list_s3_objects(self, bucket_name: str, prefix: str = "") -> str:
        try:
            s3 = self.get_client('s3')
            response = s3.list_objects_v2(Bucket=bucket_name, Prefix=prefix)
            
            if 'Contents' not in response:
                return f"No objects found in bucket {bucket_name}"
                
            objects = [
                {
                    "Key": obj['Key'],
                    "Size": obj['Size'],
                    "LastModified": self._format_date(obj['LastModified'])
                }
                for obj in response['Contents']
            ]
            return json.dumps(objects, indent=2)
        except Exception as e:
            return f"Error listing objects in {bucket_name}: {str(e)}"

    def list_ec2_instances(self, region_name: str) -> str:
        try:
            ec2 = self.get_client('ec2', region_name)
            response = ec2.describe_instances()
            instances = []
            
            for reservation in response.get('Reservations', []):
                for instance in reservation.get('Instances', []):
                    name = "N/A"
                    if 'Tags' in instance:
                        name = next((t['Value'] for t in instance['Tags'] if t['Key'] == 'Name'), "N/A")
                                
                    instances.append({
                        "InstanceId": instance['InstanceId'],
                        "Name": name,
                        "InstanceType": instance['InstanceType'],
                        "State": instance['State']['Name'],
                        "PublicIp": instance.get('PublicIpAddress', 'N/A'),
                        "AvailabilityZone": instance.get('Placement', {}).get('AvailabilityZone', 'N/A'),
                        "LaunchTime": self._format_date(instance['LaunchTime'])
                    })
            
            if not instances:
                return f"No EC2 instances found in region {region_name}."
                
            return json.dumps(instances, indent=2)
        except Exception as e:
            return f"Error listing instances in {region_name}: {str(e)}"

    def list_lambda_functions(self, region_name: str) -> str:
        try:
            lambda_client = self.get_client('lambda', region_name)
            response = lambda_client.list_functions()
            functions = []
            
            for func in response.get('Functions', []):
                functions.append({
                    "FunctionName": func['FunctionName'],
                    "Runtime": func['Runtime'],
                    "Handler": func['Handler'],
                    "LastModified": func['LastModified'],
                    "CodeSize": func['CodeSize'],
                    "Description": func.get('Description', "")
                })
                
            if not functions:
                return f"No Lambda functions found in region {region_name}."
                
            return json.dumps(functions, indent=2)
        except Exception as e:
            return f"Error listing lambda functions: {str(e)}"

    def list_dynamodb_tables(self, region_name: str) -> str:
        try:
            dynamo = self.get_client('dynamodb', region_name)
            response = dynamo.list_tables()
            table_names = response.get('TableNames', [])
            
            if not table_names:
                return f"No DynamoDB tables found in region {region_name}."
            
            # Fetch details for each table (Summary)
            formatted_tables = []
            for name in table_names:
                # We catch errors per table to allow partial results
                try:
                    desc = dynamo.describe_table(TableName=name)['Table']
                    formatted_tables.append({
                        "TableName": name,
                        "Status": desc['TableStatus'],
                        "ItemCount": desc.get('ItemCount', 0),
                        "SizeBytes": desc.get('TableSizeBytes', 0),
                        "CreationDateTime": self._format_date(desc['CreationDateTime'])
                    })
                except Exception:
                    formatted_tables.append({"TableName": name, "Error": "Could not fetch details"})

            return json.dumps(formatted_tables, indent=2)
        except Exception as e:
            return f"Error listing DynamoDB tables: {str(e)}"


# Instantiate Manager
aws_manager = AWSResourceManager()

# --- MCP Tools Registration ---

@mcp.tool()
def list_s3_buckets() -> str:
    """Lists all S3 buckets in the AWS account."""
    return aws_manager.list_s3_buckets()

@mcp.tool()
def list_s3_objects(bucket_name: str, prefix: str = "") -> str:
    """Lists objects in a specific S3 bucket."""
    return aws_manager.list_s3_objects(bucket_name, prefix)

@mcp.tool()
def list_ec2_instances(region_name: str = "us-east-1") -> str:
    """Lists all EC2 instances in a specific region."""
    return aws_manager.list_ec2_instances(region_name)

@mcp.tool()
def list_lambda_functions(region_name: str = "us-east-1") -> str:
    """
    Lists all Lambda functions in a specific region.
    Returns function name, runtime, and other metadata.
    """
    return aws_manager.list_lambda_functions(region_name)

@mcp.tool()
def list_dynamodb_tables(region_name: str = "us-east-1") -> str:
    """
    Lists all DynamoDB tables in a specific region.
    Includes summary details like item count and status.
    """
    return aws_manager.list_dynamodb_tables(region_name)

if __name__ == "__main__":
    mcp.run()
