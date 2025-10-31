#!/usr/bin/env python3
"""
Screenshot Organizer Backend
Scans screenshots, uses OpenAI Vision API to analyze them, and stores metadata in SQLite
"""

from flask import Flask, jsonify, send_file, request, send_from_directory
from flask_cors import CORS
import sqlite3
import os
import base64
import json
from pathlib import Path
from datetime import datetime
import hashlib
from openai import OpenAI

app = Flask(__name__, static_folder='..', static_url_path='')
CORS(app)

# Configuration
DB_PATH = "screenshots.db"

def get_screenshots_dir():
    """Get screenshots directory from settings or default"""
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    
    # Check if screenshots_dir is set in settings
    cursor.execute("SELECT value FROM settings WHERE key = 'screenshots_dir'")
    result = cursor.fetchone()
    conn.close()
    
    if result and result[0] and os.path.exists(result[0]):
        return result[0]
    
    # Default fallback
    default_dir = os.path.expanduser("~/Pictures/Pics/Screenshots")
    return default_dir

# OpenAI Configuration
OPENAI_API_KEY = os.environ.get("OPENAI_API_KEY")

# Initialize OpenAI client
client = OpenAI(
    api_key=OPENAI_API_KEY
) if OPENAI_API_KEY else None

def init_db():
    """Initialize the SQLite database"""
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS screenshots (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            filename TEXT UNIQUE NOT NULL,
            filepath TEXT NOT NULL,
            file_hash TEXT UNIQUE NOT NULL,
            file_size INTEGER,
            created_at TEXT,
            modified_at TEXT,
            width INTEGER,
            height INTEGER,
            ai_description TEXT,
            ai_tags TEXT,
            ai_text_content TEXT,
            analyzed_at TEXT,
            analysis_model TEXT,
            analysis_cost REAL,
            is_favorite INTEGER DEFAULT 0,
            favorited_at TEXT
        )
    """)
    
    # Add settings table
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS settings (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL,
            updated_at TEXT
        )
    """)
    
    # Set default settings if they don't exist
    default_screenshots_dir = os.path.expanduser("~/Pictures/Pics/Screenshots")
    cursor.execute("""
        INSERT OR IGNORE INTO settings (key, value, updated_at) 
        VALUES 
            ('auto_scan_enabled', 'false', datetime('now')),
            ('scan_interval_minutes', '30', datetime('now')),
            ('max_scans_per_batch', '5', datetime('now')),
            ('single_scan_mode', 'true', datetime('now')),
            ('grid_size', '20', datetime('now')),
            ('screenshots_dir', ?, datetime('now'))
    """, (default_screenshots_dir,))
    
    cursor.execute("""
        CREATE INDEX IF NOT EXISTS idx_filename ON screenshots(filename)
    """)
    
    cursor.execute("""
        CREATE INDEX IF NOT EXISTS idx_tags ON screenshots(ai_tags)
    """)
    
    conn.commit()
    conn.close()

def get_file_hash(filepath):
    """Generate MD5 hash of file"""
    hash_md5 = hashlib.md5()
    with open(filepath, "rb") as f:
        for chunk in iter(lambda: f.read(4096), b""):
            hash_md5.update(chunk)
    return hash_md5.hexdigest()

def get_image_dimensions(filepath):
    """Get image dimensions using PIL"""
    try:
        from PIL import Image
        with Image.open(filepath) as img:
            return img.width, img.height
    except:
        return None, None

def encode_image_base64(filepath):
    """Encode image to base64 for OpenAI API"""
    with open(filepath, "rb") as image_file:
        return base64.b64encode(image_file.read()).decode('utf-8')

def analyze_screenshot_with_ai(filepath):
    """Use OpenRouter API (with OpenAI-compatible client) to analyze screenshot"""
    if not client:
        return {
            "description": "No API key configured",
            "tags": "unanalyzed",
            "text_content": ""
        }
    
    try:
        base64_image = encode_image_base64(filepath)
        file_ext = os.path.splitext(filepath)[1].lower()
        
        # Determine mime type
        mime_types = {
            '.png': 'image/png',
            '.jpg': 'image/jpeg',
            '.jpeg': 'image/jpeg',
            '.gif': 'image/gif',
            '.webp': 'image/webp'
        }
        mime_type = mime_types.get(file_ext, 'image/png')
        
        response = client.chat.completions.create(
            model="gpt-4o-mini",
            messages=[
                {
                    "role": "user",
                    "content": [
                        {
                            "type": "text",
                            "text": """Analyze this screenshot and provide:
1. A concise description (1-2 sentences) of what's shown. matter of fact. don't be verbose. (e.g. screenshot of webapp, or photo of man. if you can identify the person or thing in the photo include that. 
2. keywords of what is is: (e.g. confirmation, error, meme, art, illustration, chart, etc.)
3. Any visible text content (extract key text if present)

Format your response as JSON:
{
  "description": "...",
  "tags": "tag1, tag2, tag3",
  "text_content": "..."
}"""
                        },
                        {
                            "type": "image_url",
                            "image_url": {
                                "url": f"data:{mime_type};base64,{base64_image}",
                                "detail": "low"
                            }
                        }
                    ]
                }
            ],
            max_tokens=500
        )
        
        result_text = response.choices[0].message.content
        
        # Calculate approximate cost (OpenRouter provides this in response)
        # GPT-4o-mini on OpenRouter: ~$0.00015 per image (low detail)
        cost = 0.00015
        
        # Clean up the response text and parse as JSON
        try:
            # Remove markdown formatting if present
            cleaned_text = result_text.strip()
            if cleaned_text.startswith('```json'):
                cleaned_text = cleaned_text[7:]  # Remove ```json
            if cleaned_text.endswith('```'):
                cleaned_text = cleaned_text[:-3]  # Remove ```
            cleaned_text = cleaned_text.strip()
            
            # Try to parse as JSON
            result = json.loads(cleaned_text)
            result["cost"] = cost
        except json.JSONDecodeError:
            # If not valid JSON, parse manually
            result = {
                "description": result_text[:200],
                "tags": "screenshot",
                "text_content": "",
                "cost": cost
            }
        
        return result
        
    except Exception as e:
        print(f"Error analyzing image: {e}")
        return {
            "description": f"Error: {str(e)}",
            "tags": "error",
            "text_content": "",
            "cost": 0.0
        }

@app.route('/api/scan', methods=['POST'])
def scan_screenshots():
    """Scan the screenshots directory and analyze new files (respects settings)"""
    SCREENSHOTS_DIR = get_screenshots_dir()
    if not os.path.exists(SCREENSHOTS_DIR):
        return jsonify({"error": f"Screenshots directory not found: {SCREENSHOTS_DIR}"}), 404
    
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    
    # Get settings
    cursor.execute("SELECT value FROM settings WHERE key = 'max_scans_per_batch'")
    max_batch = int(cursor.fetchone()[0])
    
    cursor.execute("SELECT value FROM settings WHERE key = 'single_scan_mode'")
    single_mode = cursor.fetchone()[0] == 'true'
    
    max_to_scan = 1 if single_mode else max_batch
    
    stats = {
        "total_files": 0,
        "new_files": 0,
        "existing_files": 0,
        "errors": 0,
        "skipped": 0,
        "max_batch": max_to_scan
    }
    
    # Get existing hashes
    cursor.execute("SELECT file_hash FROM screenshots")
    existing_hashes = set(row[0] for row in cursor.fetchall())
    
    # Supported image formats
    image_extensions = {'.png', '.jpg', '.jpeg', '.gif', '.webp', '.bmp'}
    
    scanned_count = 0
    
    for filename in os.listdir(SCREENSHOTS_DIR):
        filepath = os.path.join(SCREENSHOTS_DIR, filename)
        
        if not os.path.isfile(filepath):
            continue
            
        file_ext = os.path.splitext(filename)[1].lower()
        if file_ext not in image_extensions:
            continue
        
        stats["total_files"] += 1
        
        try:
            # Get file info
            file_hash = get_file_hash(filepath)
            
            if file_hash in existing_hashes:
                stats["existing_files"] += 1
                continue
            
            # Check if we've reached the scan limit
            if scanned_count >= max_to_scan:
                stats["skipped"] += 1
                continue
            
            file_stat = os.stat(filepath)
            width, height = get_image_dimensions(filepath)
            
            # Analyze with AI
            ai_result = analyze_screenshot_with_ai(filepath)
            
            # Insert into database
            cursor.execute("""
                INSERT INTO screenshots 
                (filename, filepath, file_hash, file_size, created_at, modified_at,
                 width, height, ai_description, ai_tags, ai_text_content, 
                 analyzed_at, analysis_model, analysis_cost)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, (
                filename,
                filepath,
                file_hash,
                file_stat.st_size,
                datetime.fromtimestamp(file_stat.st_birthtime).isoformat(),
                datetime.fromtimestamp(file_stat.st_mtime).isoformat(),
                width,
                height,
                ai_result["description"],
                ai_result["tags"],
                ai_result.get("text_content", ""),
                datetime.now().isoformat(),
                "gpt-4o-mini",
                ai_result.get("cost", 0.0)
            ))
            
            stats["new_files"] += 1
            scanned_count += 1
            
        except Exception as e:
            print(f"Error processing {filename}: {e}")
            stats["errors"] += 1
    
    conn.commit()
    conn.close()
    
    return jsonify(stats)

@app.route('/api/screenshots', methods=['GET'])
def get_screenshots():
    """Get all screenshots with optional filtering"""
    search = request.args.get('search', '')
    offset = int(request.args.get('offset', 0))
    
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    cursor = conn.cursor()
    
    # Get grid_size setting as default limit
    cursor.execute("SELECT value FROM settings WHERE key = 'grid_size'")
    default_limit = int(cursor.fetchone()[0])
    limit = int(request.args.get('limit', default_limit))
    
    if search:
        cursor.execute("""
            SELECT * FROM screenshots 
            WHERE ai_description LIKE ? 
               OR ai_tags LIKE ? 
               OR ai_text_content LIKE ?
               OR filename LIKE ?
            ORDER BY created_at DESC
            LIMIT ? OFFSET ?
        """, (f'%{search}%', f'%{search}%', f'%{search}%', f'%{search}%', limit, offset))
    else:
        cursor.execute("""
            SELECT * FROM screenshots 
            ORDER BY created_at DESC
            LIMIT ? OFFSET ?
        """, (limit, offset))
    
    screenshots = [dict(row) for row in cursor.fetchall()]
    
    # Get total count
    if search:
        cursor.execute("""
            SELECT COUNT(*) FROM screenshots 
            WHERE ai_description LIKE ? 
               OR ai_tags LIKE ? 
               OR ai_text_content LIKE ?
               OR filename LIKE ?
        """, (f'%{search}%', f'%{search}%', f'%{search}%', f'%{search}%'))
    else:
        cursor.execute("SELECT COUNT(*) FROM screenshots")
    
    total_count = cursor.fetchone()[0]
    
    conn.close()
    
    return jsonify({
        "screenshots": screenshots,
        "total": total_count,
        "limit": limit,
        "offset": offset
    })

@app.route('/api/screenshot/<int:screenshot_id>', methods=['GET'])
def get_screenshot_detail(screenshot_id):
    """Get detailed information about a specific screenshot"""
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    cursor = conn.cursor()
    
    cursor.execute("SELECT * FROM screenshots WHERE id = ?", (screenshot_id,))
    screenshot = cursor.fetchone()
    
    conn.close()
    
    if not screenshot:
        return jsonify({"error": "Screenshot not found"}), 404
    
    return jsonify(dict(screenshot))

@app.route('/api/image/<int:screenshot_id>', methods=['GET'])
def serve_image(screenshot_id):
    """Serve the actual image file"""
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    
    cursor.execute("SELECT filepath FROM screenshots WHERE id = ?", (screenshot_id,))
    result = cursor.fetchone()
    
    conn.close()
    
    if not result:
        return jsonify({"error": "Screenshot not found"}), 404
    
    filepath = result[0]
    
    if not os.path.exists(filepath):
        return jsonify({"error": "File not found on disk"}), 404
    
    return send_file(filepath)

@app.route('/api/stats', methods=['GET'])
def get_stats():
    """Get statistics about the screenshot collection"""
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    
    cursor.execute("SELECT COUNT(*) FROM screenshots")
    total_screenshots = cursor.fetchone()[0]
    
    cursor.execute("SELECT SUM(file_size) FROM screenshots")
    total_size = cursor.fetchone()[0] or 0
    
    cursor.execute("""
        SELECT ai_tags, COUNT(*) as count 
        FROM screenshots 
        WHERE ai_tags IS NOT NULL 
        GROUP BY ai_tags 
        ORDER BY count DESC 
        LIMIT 10
    """)
    top_tags = [{"tag": row[0], "count": row[1]} for row in cursor.fetchall()]
    
    conn.close()
    
    return jsonify({
        "total_screenshots": total_screenshots,
        "total_size_mb": round(total_size / (1024 * 1024), 2),
        "top_tags": top_tags
    })

@app.route('/api/tags', methods=['GET'])
def get_all_tags():
    """Get all unique tags with counts"""
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    
    cursor.execute("""
        SELECT ai_tags FROM screenshots 
        WHERE ai_tags IS NOT NULL AND ai_tags != ''
    """)
    
    # Parse and count all tags
    tag_counts = {}
    for row in cursor.fetchall():
        tags = row[0].split(',')
        for tag in tags:
            tag = tag.strip()
            if tag:
                tag_counts[tag] = tag_counts.get(tag, 0) + 1
    
    # Sort by count
    sorted_tags = sorted(tag_counts.items(), key=lambda x: x[1], reverse=True)
    
    conn.close()
    
    return jsonify({
        "tags": [{"tag": tag, "count": count} for tag, count in sorted_tags]
    })

@app.route('/api/settings', methods=['GET'])
def get_settings():
    """Get all settings"""
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    cursor = conn.cursor()
    
    cursor.execute("SELECT key, value FROM settings")
    settings = {row['key']: row['value'] for row in cursor.fetchall()}
    
    conn.close()
    
    return jsonify(settings)

@app.route('/api/settings', methods=['POST'])
def update_settings():
    """Update settings"""
    data = request.json
    
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    
    for key, value in data.items():
        cursor.execute("""
            INSERT OR REPLACE INTO settings (key, value, updated_at)
            VALUES (?, ?, datetime('now'))
        """, (key, str(value)))
    
    conn.commit()
    conn.close()
    
    return jsonify({"success": True})

@app.route('/api/screenshot/<int:screenshot_id>/favorite', methods=['POST'])
def toggle_favorite(screenshot_id):
    """Toggle favorite status for a screenshot"""
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    
    # Get current status
    cursor.execute("SELECT is_favorite FROM screenshots WHERE id = ?", (screenshot_id,))
    result = cursor.fetchone()
    
    if not result:
        conn.close()
        return jsonify({"error": "Screenshot not found"}), 404
    
    new_status = 0 if result[0] == 1 else 1
    favorited_at = datetime.now().isoformat() if new_status == 1 else None
    
    cursor.execute("""
        UPDATE screenshots 
        SET is_favorite = ?, favorited_at = ?
        WHERE id = ?
    """, (new_status, favorited_at, screenshot_id))
    
    conn.commit()
    conn.close()
    
    return jsonify({"success": True, "is_favorite": new_status == 1})

@app.route('/api/favorites', methods=['GET'])
def get_favorites():
    """Get all favorited screenshots"""
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    cursor = conn.cursor()
    
    cursor.execute("""
        SELECT * FROM screenshots 
        WHERE is_favorite = 1
        ORDER BY favorited_at DESC
    """)
    
    favorites = [dict(row) for row in cursor.fetchall()]
    
    conn.close()
    
    return jsonify({"favorites": favorites, "total": len(favorites)})

@app.route('/api/screenshot/<int:screenshot_id>/analyze', methods=['POST'])
def analyze_single_screenshot(screenshot_id):
    """Analyze a specific screenshot by ID"""
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    cursor = conn.cursor()
    
    # Get screenshot info
    cursor.execute("SELECT * FROM screenshots WHERE id = ?", (screenshot_id,))
    screenshot = cursor.fetchone()
    
    if not screenshot:
        conn.close()
        return jsonify({"error": "Screenshot not found"}), 404
    
    # Check if already analyzed
    if screenshot['ai_description'] and screenshot['ai_description'] != 'No API key configured':
        conn.close()
        return jsonify({"error": "Already analyzed", "screenshot": dict(screenshot)}), 400
    
    filepath = screenshot['filepath']
    
    if not os.path.exists(filepath):
        conn.close()
        return jsonify({"error": "File not found on disk"}), 404
    
    try:
        # Analyze with AI
        ai_result = analyze_screenshot_with_ai(filepath)
        
        # Update database
        cursor.execute("""
            UPDATE screenshots 
            SET ai_description = ?,
                ai_tags = ?,
                ai_text_content = ?,
                analyzed_at = ?,
                analysis_model = ?,
                analysis_cost = ?
            WHERE id = ?
        """, (
            ai_result["description"],
            ai_result["tags"],
            ai_result.get("text_content", ""),
            datetime.now().isoformat(),
            "gpt-4o-mini",
            ai_result.get("cost", 0.0),
            screenshot_id
        ))
        
        conn.commit()
        
        # Get updated screenshot
        cursor.execute("SELECT * FROM screenshots WHERE id = ?", (screenshot_id,))
        updated_screenshot = dict(cursor.fetchone())
        
        conn.close()
        
        return jsonify({
            "success": True,
            "screenshot": updated_screenshot,
            "cost": ai_result.get("cost", 0.0)
        })
        
    except Exception as e:
        conn.close()
        print(f"Error analyzing screenshot {screenshot_id}: {e}")
        return jsonify({"error": str(e)}), 500

@app.route('/api/screenshot/<int:screenshot_id>/update', methods=['POST'])
def update_screenshot_metadata(screenshot_id):
    """Update screenshot metadata (description, tags, filename)"""
    data = request.get_json()
    
    if not data:
        return jsonify({"error": "No data provided"}), 400
    
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    
    # Get current screenshot info
    cursor.execute("SELECT filepath, filename FROM screenshots WHERE id = ?", (screenshot_id,))
    result = cursor.fetchone()
    
    if not result:
        conn.close()
        return jsonify({"error": "Screenshot not found"}), 404
    
    current_filepath, current_filename = result
    
    try:
        # Update metadata in database
        update_fields = []
        update_values = []
        
        if 'description' in data:
            update_fields.append('ai_description = ?')
            update_values.append(data['description'])
        
        if 'tags' in data:
            update_fields.append('ai_tags = ?')
            update_values.append(data['tags'])
        
        if 'text_content' in data:
            update_fields.append('ai_text_content = ?')
            update_values.append(data['text_content'])
        
        # Handle filename change (rename file)
        if 'filename' in data and data['filename'] != current_filename:
            new_filename = data['filename']
            # Ensure it has a valid extension
            if not any(new_filename.lower().endswith(ext) for ext in ['.png', '.jpg', '.jpeg', '.gif', '.webp', '.bmp']):
                # Keep original extension
                original_ext = os.path.splitext(current_filename)[1]
                new_filename = new_filename + original_ext
            
            new_filepath = os.path.join(os.path.dirname(current_filepath), new_filename)
            
            # Rename the actual file
            if os.path.exists(current_filepath):
                os.rename(current_filepath, new_filepath)
                print(f"Renamed file: {current_filepath} -> {new_filepath}")
            
            update_fields.append('filename = ?')
            update_fields.append('filepath = ?')
            update_values.append(new_filename)
            update_values.append(new_filepath)
        
        if update_fields:
            update_values.append(screenshot_id)
            query = f"UPDATE screenshots SET {', '.join(update_fields)} WHERE id = ?"
            cursor.execute(query, update_values)
        
        conn.commit()
        conn.close()
        
        return jsonify({
            "message": "Screenshot updated successfully",
            "updated_fields": list(data.keys())
        })
        
    except Exception as e:
        conn.close()
        return jsonify({"error": f"Update failed: {str(e)}"}), 500

# Serve the main HTML file
@app.route('/')
def index():
    return send_from_directory('..', 'index.html')

# Serve static files (CSS, JS)
@app.route('/<path:path>')
def serve_static(path):
    return send_from_directory('..', path)

if __name__ == '__main__':
    init_db()
    port = int(os.environ.get('PORT', 5001))
    print(f"Starting Screenshot Organizer Backend on port {port}")
    SCREENSHOTS_DIR = get_screenshots_dir()
    print(f"Screenshots directory: {SCREENSHOTS_DIR}")
    print(f"Using OpenAI API: {'✓' if OPENAI_API_KEY else '✗'}")
    app.run(debug=True, host='0.0.0.0', port=port)

