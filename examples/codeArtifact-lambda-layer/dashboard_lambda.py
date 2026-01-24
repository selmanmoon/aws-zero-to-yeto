"""
Dashboard Generator Lambda Function
====================================
Triggered by S3 .json creation in the 'metadata/' prefix.
Scans all metadata files and generates a Tailwind CSS styled dashboard.
"""

import json
import os
import boto3
from datetime import datetime
import time

# Initialize S3 client
s3_client = boto3.client('s3')
cf_client = boto3.client('cloudfront')

# Tailwind CSS Dashboard Template
HTML_TEMPLATE = '''<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>PPTX to PDF Converter - Dashboard</title>
    <script src="https://cdn.tailwindcss.com"></script>
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&display=swap" rel="stylesheet">
    <style>
        body {{ font-family: 'Inter', sans-serif; }}
        .gradient-bg {{
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
        }}
        .glass-card {{
            background: rgba(255, 255, 255, 0.95);
            backdrop-filter: blur(10px);
            border: 1px solid rgba(255, 255, 255, 0.2);
        }}
        .table-row:hover {{
            background: linear-gradient(90deg, rgba(102, 126, 234, 0.05) 0%, rgba(118, 75, 162, 0.05) 100%);
        }}
        @keyframes fadeIn {{
            from {{ opacity: 0; transform: translateY(10px); }}
            to {{ opacity: 1; transform: translateY(0); }}
        }}
        .fade-in {{
            animation: fadeIn 0.5s ease-out forwards;
        }}
    </style>
</head>
<body class="min-h-screen gradient-bg">
    <!-- Header -->
    <header class="py-8 px-4">
        <div class="max-w-6xl mx-auto text-center">
            <div class="inline-flex items-center justify-center w-16 h-16 rounded-2xl bg-white/20 backdrop-blur mb-4">
                <svg class="w-8 h-8 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"></path>
                </svg>
            </div>
            <h1 class="text-4xl font-bold text-white mb-2">PPTX to PDF Converter</h1>
            <p class="text-white/80 text-lg">Serverless Document Conversion Dashboard</p>
        </div>
    </header>

    <!-- Main Content -->
    <main class="px-4 pb-12">
        <div class="max-w-6xl mx-auto">
            <!-- Stats Cards -->
            <div class="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
                <div class="glass-card rounded-2xl p-6 shadow-xl fade-in" style="animation-delay: 0.1s;">
                    <div class="flex items-center">
                        <div class="w-12 h-12 rounded-xl bg-gradient-to-br from-blue-500 to-blue-600 flex items-center justify-center">
                            <svg class="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 21h10a2 2 0 002-2V9.414a1 1 0 00-.293-.707l-5.414-5.414A1 1 0 0012.586 3H7a2 2 0 00-2 2v14a2 2 0 002 2z"></path>
                            </svg>
                        </div>
                        <div class="ml-4">
                            <p class="text-sm text-gray-500 font-medium">Total Documents</p>
                            <p class="text-2xl font-bold text-gray-800">{total_documents}</p>
                        </div>
                    </div>
                </div>
                <div class="glass-card rounded-2xl p-6 shadow-xl fade-in" style="animation-delay: 0.2s;">
                    <div class="flex items-center">
                        <div class="w-12 h-12 rounded-xl bg-gradient-to-br from-purple-500 to-purple-600 flex items-center justify-center">
                            <svg class="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10"></path>
                            </svg>
                        </div>
                        <div class="ml-4">
                            <p class="text-sm text-gray-500 font-medium">Total Slides</p>
                            <p class="text-2xl font-bold text-gray-800">{total_slides}</p>
                        </div>
                    </div>
                </div>
                <div class="glass-card rounded-2xl p-6 shadow-xl fade-in" style="animation-delay: 0.3s;">
                    <div class="flex items-center">
                        <div class="w-12 h-12 rounded-xl bg-gradient-to-br from-green-500 to-green-600 flex items-center justify-center">
                            <svg class="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"></path>
                            </svg>
                        </div>
                        <div class="ml-4">
                            <p class="text-sm text-gray-500 font-medium">Last Updated</p>
                            <p class="text-lg font-bold text-gray-800">{last_updated}</p>
                        </div>
                    </div>
                </div>
            </div>

            <!-- Documents Table -->
            <div class="glass-card rounded-2xl shadow-xl overflow-hidden fade-in" style="animation-delay: 0.4s;">
                <div class="px-6 py-4 border-b border-gray-100">
                    <h2 class="text-xl font-semibold text-gray-800">Converted Documents</h2>
                </div>
                <div class="overflow-x-auto">
                    <table class="w-full">
                        <thead>
                            <tr class="bg-gray-50/50">
                                <th class="px-6 py-4 text-left text-xs font-semibold text-gray-500 uppercase tracking-wider">Document Name</th>
                                <th class="px-6 py-4 text-center text-xs font-semibold text-gray-500 uppercase tracking-wider">Slides</th>
                                <th class="px-6 py-4 text-center text-xs font-semibold text-gray-500 uppercase tracking-wider">Date</th>
                                <th class="px-6 py-4 text-center text-xs font-semibold text-gray-500 uppercase tracking-wider">Action</th>
                            </tr>
                        </thead>
                        <tbody class="divide-y divide-gray-100">
                            {table_rows}
                        </tbody>
                    </table>
                </div>
                {empty_state}
            </div>

            <!-- Footer -->
            <div class="mt-8 text-center">
                <p class="text-white/60 text-sm">
                    Powered by AWS Lambda • CloudFront • S3
                </p>
            </div>
        </div>
    </main>
</body>
</html>'''

# Table row template
TABLE_ROW_TEMPLATE = '''
                            <tr class="table-row transition-all duration-200">
                                <td class="px-6 py-4">
                                    <div class="flex items-center">
                                        <div class="w-10 h-10 rounded-lg bg-gradient-to-br from-red-500 to-orange-500 flex items-center justify-center mr-3">
                                            <svg class="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 21h10a2 2 0 002-2V9.414a1 1 0 00-.293-.707l-5.414-5.414A1 1 0 0012.586 3H7a2 2 0 00-2 2v14a2 2 0 002 2z"></path>
                                            </svg>
                                        </div>
                                        <div>
                                            <p class="font-medium text-gray-800">{document_name}</p>
                                            <p class="text-xs text-gray-400">{original_name}</p>
                                        </div>
                                    </div>
                                </td>
                                <td class="px-6 py-4 text-center">
                                    <span class="inline-flex items-center px-3 py-1 rounded-full text-sm font-medium bg-purple-100 text-purple-800">
                                        {slide_count} slides
                                    </span>
                                </td>
                                <td class="px-6 py-4 text-center text-sm text-gray-600">{create_date}</td>
                                <td class="px-6 py-4 text-center">
                                    <a href="{pdf_path}" download 
                                       class="inline-flex items-center px-4 py-2 rounded-lg bg-gradient-to-r from-blue-500 to-purple-600 text-white text-sm font-medium hover:from-blue-600 hover:to-purple-700 transition-all duration-200 shadow-md hover:shadow-lg">
                                        <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4"></path>
                                        </svg>
                                        Download
                                    </a>
                                </td>
                            </tr>'''

# Empty state template
EMPTY_STATE_TEMPLATE = '''
                <div class="px-6 py-12 text-center">
                    <div class="inline-flex items-center justify-center w-16 h-16 rounded-full bg-gray-100 mb-4">
                        <svg class="w-8 h-8 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"></path>
                        </svg>
                    </div>
                    <h3 class="text-lg font-medium text-gray-800 mb-2">No documents yet</h3>
                    <p class="text-gray-500">Upload a PPTX file to the pptxs/ folder to get started.</p>
                </div>'''


def format_date(iso_date):
    """Format ISO date string to human-readable format."""
    try:
        dt = datetime.fromisoformat(iso_date.replace('Z', '+00:00'))
        return dt.strftime('%b %d, %Y %H:%M')
    except:
        return iso_date


def lambda_handler(event, context):
    """
    Main Lambda handler - generates dashboard HTML from metadata files.
    
    Triggered by S3 ObjectCreated events in the 'metadata/' prefix.
    """
    print("🚀 Dashboard Generator Lambda triggered")
    print(f"Event: {json.dumps(event, indent=2)}")
    
    try:
        # Get bucket name from event
        record = event['Records'][0]
        bucket_name = record['s3']['bucket']['name']
        
        print(f"📁 Processing metadata from bucket: {bucket_name}")
        
        # List all JSON files in metadata/
        print("📋 Listing metadata files...")
        response = s3_client.list_objects_v2(
            Bucket=bucket_name,
            Prefix='metadata/'
        )
        
        documents = []
        total_slides = 0
        
        if 'Contents' in response:
            for obj in response['Contents']:
                key = obj['Key']
                
                # Skip if not a JSON file
                if not key.lower().endswith('.json'):
                    continue
                
                print(f"  📄 Reading: {key}")
                
                try:
                    # Get and parse JSON
                    json_response = s3_client.get_object(Bucket=bucket_name, Key=key)
                    metadata = json.loads(json_response['Body'].read().decode('utf-8'))
                    
                    documents.append(metadata)
                    total_slides += metadata.get('slide_count', 0)
                    
                except Exception as e:
                    print(f"  ⚠️ Error reading {key}: {str(e)}")
                    continue
        
        print(f"📊 Found {len(documents)} documents with {total_slides} total slides")
        
        # Sort documents by date (newest first)
        documents.sort(key=lambda x: x.get('create_date', ''), reverse=True)
        
        # Generate table rows
        table_rows = ""
        for doc in documents:
            table_rows += TABLE_ROW_TEMPLATE.format(
                document_name=doc.get('pdf_name', 'Unknown'),
                original_name=doc.get('original_name', ''),
                slide_count=doc.get('slide_count', 0),
                create_date=format_date(doc.get('create_date', '')),
                pdf_path=doc.get('pdf_path', '#')
            )
        
        # Determine empty state
        empty_state = "" if documents else EMPTY_STATE_TEMPLATE
        
        # Generate final HTML
        last_updated = datetime.utcnow().strftime('%b %d, %Y %H:%M')
        
        html_content = HTML_TEMPLATE.format(
            total_documents=len(documents),
            total_slides=total_slides,
            last_updated=last_updated,
            table_rows=table_rows,
            empty_state=empty_state
        )
        
        # Upload index.html to S3 root
        print("📤 Uploading index.html to S3 root...")
        s3_client.put_object(
            Bucket=bucket_name,
            Key='index.html',
            Body=html_content,
            ContentType='text/html',
            CacheControl='max-age=60'
        )
        
        dist_id = os.environ.get('DISTRIBUTION_ID')

        print("✅ Dashboard generated successfully!")
        if dist_id:
            cf_client.create_invalidation(
                DistributionId=dist_id,
                InvalidationBatch={
                    'Paths': {
                        'Quantity': 1,
                        'Items': ['/*'] # Tüm siteyi tazele
                    },
                    'CallerReference': f"lambda-refresh-{str(time.time())}"
                }
            )
        print(f"✅ CloudFront cache cleared for {dist_id}")


        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Dashboard generated successfully',
                'total_documents': len(documents),
                'total_slides': total_slides
            })
        }
        
    except Exception as e:
        print(f"❌ Error generating dashboard: {str(e)}")
        import traceback
        traceback.print_exc()
        
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': str(e),
                'message': 'Failed to generate dashboard'
            })
        }
