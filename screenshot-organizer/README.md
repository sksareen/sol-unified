# Screenshot Organizer

A powerful, minimalist web application with Nordic design that uses AI to analyze, categorize, and organize your screenshots. Built with a Python Flask backend and a clean HTML/CSS/JS frontend.

## Features

- 🤖 **AI-Powered Analysis**: Uses OpenAI's GPT-4o-mini vision model to automatically analyze screenshots
- 🔍 **Smart Search**: Search by description, tags, or extracted text content
- 📊 **Statistics Dashboard**: View collection stats and most common tags
- 🎨 **Nordic Design**: Minimalist, elegant interface with soft colors and smooth interactions
- 💾 **SQLite Database**: Fast, local storage of metadata
- 🖼️ **Image Preview**: Click any screenshot for detailed view with smooth animations
- ♾️ **Infinite Scroll**: Seamlessly loads more screenshots as you scroll down

## What It Does

The Screenshot Organizer:
1. Scans your Screenshots folder for images
2. Uses AI to generate descriptions, tags, and extract visible text
3. Stores all metadata in a local SQLite database
4. Provides a beautiful, searchable web interface to browse your screenshots

## Prerequisites

- Python 3.8+
- OpenRouter API key (get one at [openrouter.ai](https://openrouter.ai))
- Modern web browser

## Installation

### 1. Set up the Backend

```bash
cd backend
python3 -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
pip install -r requirements.txt
```

### 2. Configure OpenRouter API Key (Optional)

The API key is already configured in the code. To override it, set an environment variable:

```bash
export OPENROUTER_API_KEY='your-api-key-here'
```

Or add it to your shell profile (~/.zshrc or ~/.bashrc):

```bash
echo 'export OPENROUTER_API_KEY="your-api-key-here"' >> ~/.zshrc
source ~/.zshrc
```

**Note**: A key is hardcoded in `main.py` so you can start using it immediately!

### 3. Update Screenshots Path (Optional)

The default path is `~/Pictures/Pics/Screenshots`. To change it, edit `backend/main.py`:

```python
SCREENSHOTS_DIR = os.path.expanduser("~/your/custom/path")
```

## Usage

### 1. Start the Backend

```bash
cd backend
source venv/bin/activate  # If not already activated
python main.py
```

The backend will start on `http://localhost:5001`

### 2. Open the Frontend

Open `index.html` in your web browser, or serve it with a simple HTTP server:

```bash
# From the screenshot-organizer directory
python3 -m http.server 8000
```

Then visit `http://localhost:8000`

### 3. Scan Your Screenshots

1. Click the **SCAN FOLDER** button
2. Wait for the AI to analyze your screenshots (this may take a while for large collections)
3. Browse, search, and explore!

## Features Guide

### Scanning
- Click **SCAN FOLDER** to analyze new screenshots
- The app only processes new files (won't re-analyze existing ones)
- Progress shown in status bar

### Searching
- Enter keywords in the search bar
- Search across descriptions, tags, text content, and filenames
- Results update in real-time

### Statistics
- Click **STATS** to view collection statistics
- See total screenshots, storage size, and popular tags

### Detail View
- Click any screenshot card for detailed information
- View full-size image
- See all metadata, tags, and extracted text

## Technical Details

### Backend (`backend/main.py`)
- **Flask** web server with CORS support
- **SQLite** database for metadata storage
- **OpenAI API** for image analysis
- **PIL** for image dimension extraction

### Frontend
- Pure HTML/CSS/JavaScript (no frameworks)
- Responsive grid layout
- Brutalist design aesthetic
- Client-side pagination
- Modal detail view

### Database Schema
```sql
CREATE TABLE screenshots (
    id INTEGER PRIMARY KEY,
    filename TEXT UNIQUE,
    filepath TEXT,
    file_hash TEXT UNIQUE,
    file_size INTEGER,
    created_at TEXT,
    modified_at TEXT,
    width INTEGER,
    height INTEGER,
    ai_description TEXT,
    ai_tags TEXT,
    ai_text_content TEXT,
    analyzed_at TEXT,
    analysis_model TEXT
)
```

## API Endpoints

- `POST /api/scan` - Scan screenshots folder for new files
- `GET /api/screenshots` - Get paginated list of screenshots with optional search
- `GET /api/screenshot/<id>` - Get detailed info for specific screenshot
- `GET /api/image/<id>` - Serve the actual image file
- `GET /api/stats` - Get collection statistics

## Cost Considerations

Using OpenRouter with GPT-4o-mini vision costs approximately:
- **$0.00015 per image** (at current pricing through OpenRouter)
- For 1000 screenshots: ~$0.15

The app uses "low" detail mode to minimize costs while maintaining good analysis quality.

**OpenRouter Benefits**:
- Access to multiple AI models
- Competitive pricing
- No separate OpenAI account needed
- Usage tracking and credits system

## Troubleshooting

### Backend won't start
- Ensure Python dependencies are installed: `pip install -r requirements.txt`
- Check that port 5001 is available
- The OpenRouter API key is configured in the code by default

### Images not loading
- Check that the Screenshots path in `main.py` is correct
- Ensure the backend is running
- Check browser console for CORS errors

### AI analysis failing
- Verify your OpenRouter API key has sufficient credits at [openrouter.ai](https://openrouter.ai/credits)
- Check backend terminal for error messages
- Ensure images are in supported formats (PNG, JPG, GIF, WebP)
- Try testing the API key with a manual request

### Search not working
- Make sure screenshots have been scanned first
- Check that the database file exists (`screenshots.db`)
- Try clearing search and rescanning

## Future Enhancements

- [ ] Tag editing and manual categorization
- [ ] Bulk operations (delete, export)
- [ ] Advanced filtering (date range, size, dimensions)
- [ ] Cloud storage integration
- [ ] Duplicate detection
- [ ] Custom AI prompts
- [ ] Export to various formats

## File Structure

```
screenshot-organizer/
├── backend/
│   ├── main.py              # Flask backend server
│   ├── requirements.txt     # Python dependencies
│   └── screenshots.db       # SQLite database (created on first run)
├── index.html               # Main HTML interface
├── styles.css               # Brutalist styling
├── script.js                # Frontend JavaScript
└── README.md               # This file
```

## Design Philosophy

This application embraces Nordic/Scandinavian design principles:
- **Minimalism**: Clean, uncluttered interface
- **Light & Airy**: Soft colors and plenty of whitespace
- **Functionality**: Every element serves a purpose
- **Subtle Elegance**: Smooth animations and refined interactions
- **User Comfort**: Easy on the eyes, pleasant to use

## Credits

Built with:
- OpenRouter API (using GPT-4o-mini Vision)
- Flask & Python
- Pure HTML/CSS/JavaScript
- SQLite

Get your own OpenRouter API key at [openrouter.ai](https://openrouter.ai)

