import json
import os
from datetime import datetime

def handler(event, context):
    """
    AWS Lambda handler function
    """
    try:
        # Response body
        response_body = {
            "message": "AWS ZERO to YETO - Lambda Örneği (Direct AWS CLI)",
            "event": event,
            "timestamp": datetime.now().isoformat(),
            "function_name": os.environ.get('AWS_LAMBDA_FUNCTION_NAME', 'unknown'),
            "function_version": os.environ.get('AWS_LAMBDA_FUNCTION_VERSION', 'unknown'),
            "deployment_method": "Direct AWS CLI"
        }
        
        # Response
        response = {
            "statusCode": 200,
            "headers": {
                "Content-Type": "application/json",
                "Access-Control-Allow-Origin": "*"
            },
            "body": json.dumps(response_body, indent=2)
        }
        
        return response
        
    except Exception as e:
        # Error response
        error_response = {
            "statusCode": 500,
            "headers": {
                "Content-Type": "application/json",
                "Access-Control-Allow-Origin": "*"
            },
            "body": json.dumps({
                "error": str(e),
                "message": "Lambda function error"
            }, indent=2)
        }
        
        return error_response
