# Recall - Remember Everything. Ace Every Exam.

An AI-powered study platform that helps students master their subjects through smart note digitization, spaced repetition, and collaborative learning.

![Version](https://img.shields.io/badge/version-0.2.0-blue)
![Status](https://img.shields.io/badge/status-beta-yellow)
![License](https://img.shields.io/badge/license-MIT-green)

---

## 🎯 What is Recall?

Recall transforms the way students study by converting physical notes into digital flashcards with intelligent spaced repetition.

**Key Features:**
- 📸 **Note Digitization** - Upload photos or PDFs of your notes
- 🤖 **OCR Text Extraction** - Automatic text extraction from images
- 🗂️ **Smart Flashcards** - Create flashcards manually or from notes
- 🧠 **Spaced Repetition** - SuperMemo-2 algorithm for optimal retention
- 🤝 **Collaborative Learning** - Share notes publicly or keep them private
- 📊 **Progress Tracking** - Monitor your study streaks and performance
- 🏷️ **Smart Organization** - Organize by subject, topic, and custom tags

---

## 👥 Target Audience

Recall is designed for professional and competitive exam students:

- **CA** (Chartered Accountancy)
- **CMA** (Cost & Management Accountant)
- **CS** (Company Secretary)
- **CFA** (Chartered Financial Analyst)
- **Engineering** entrance exams (JEE, GATE)
- **Medical** entrance exams (NEET)
- **Law** entrance exams (CLAT)
- **MBA** entrance exams (CAT, GMAT)
- Any student preparing for competitive exams

---

## 🚀 Current Status

**Phase:** Phase 1 MVP  
**Version:** v0.2.0  
**Launch:** 20 CA Intermediate students (Pilot Program)

### ✅ Completed Features (v0.2.0)

- User authentication (email/password)
- Note upload with image compression
- Public/private visibility toggle
- Note editing functionality
- Manual flashcard creation
- Flashcards inherit visibility from parent notes
- Spaced repetition review system
- Subject/topic organization
- Custom subjects and topics
- Tags system
- Progress dashboard
- Admin panel

### 🚧 In Development

- OCR implementation (Tesseract.js)
- PDF text extraction
- AI auto-flashcard generation
- Browse public notes feed
- Comments on shared notes
- Analytics dashboard

### 📅 Roadmap

**Phase 2** (Months 2-3): Scale to 150 CA Foundation students  
**Phase 3** (Months 4-6): External CA students + monetization  
**Phase 4** (Months 7-12): Multi-discipline expansion (CMA, CS, CFA, etc.)

---

## 🛠️ Tech Stack

**Frontend:**
- React 18 + Vite
- TailwindCSS + shadcn/ui components
- React Router v6

**Backend:**
- Supabase (PostgreSQL + Authentication + Storage)
- Row-Level Security (RLS) policies
- Real-time subscriptions

**Hosting & Deployment:**
- Vercel (frontend)
- Supabase (backend)

**Tools & Services:**
- Tesseract.js (OCR - planned)
- SuperMemo-2 algorithm (spaced repetition)

---

## 📦 Installation

### Prerequisites

- Node.js 18+ installed
- Supabase account
- Git installed

### Setup Instructions

1. **Clone the repository:**
```bash
   git clone https://github.com/ai1976/recall-app.git
   cd recall-app
```

2. **Install dependencies:**
```bash
   npm install
```

3. **Set up environment variables:**
   
   Create a `.env` file in the root directory:
```env
   VITE_SUPABASE_URL=your_supabase_url
   VITE_SUPABASE_ANON_KEY=your_supabase_anon_key
```

4. **Run database migrations:**
   
   Go to Supabase SQL Editor and run the schema from `docs/database-schema.sql`

5. **Start the development server:**
```bash
   npm run dev
```

6. **Open in browser:**
```
   http://localhost:5173
```

---

## 📊 Database Schema

### Core Tables

**users** - User profiles and authentication  
**notes** - Uploaded study notes with OCR text  
**flashcards** - Flashcards created from notes or independently  
**reviews** - Spaced repetition tracking (SuperMemo-2)  
**subjects** - Predefined course subjects  
**topics** - Topics within subjects  

### Storage Buckets

**note-files** - Original uploaded images/PDFs  
**flashcard-images** - Images used in flashcards  

---

## 🎨 Key Features Explained

### Public/Private Visibility

Notes and flashcards can be marked as public or private:
- **Private** (default): Only visible to the creator
- **Public**: Shared with all students for collaborative learning

Flashcards created from notes automatically inherit the parent note's visibility setting.

### Spaced Repetition

Uses the **SuperMemo-2 algorithm** to calculate optimal review intervals:
- Cards you find easy are reviewed less frequently
- Cards you struggle with appear more often
- Maximizes long-term retention with minimal study time

### Custom Organization

Beyond predefined subjects and topics, students can:
- Create custom subjects
- Add custom topics
- Tag notes with multiple keywords
- Filter and search across all metadata

---

## 🤝 Contributing

This project is currently in private beta for CA students. Once Phase 1 is complete, contribution guidelines will be added.

---

## 📝 License

This project is licensed under the MIT License - see the LICENSE file for details.

---

## 📧 Contact

**Project Maintainer:** ai1976  
**GitHub:** [@ai1976](https://github.com/ai1976)  
**Project Link:** [https://github.com/ai1976/recall-app](https://github.com/ai1976/recall-app)

---

## 🙏 Acknowledgments

- **Target Users:** CA students providing feedback during pilot program
- **Tech Stack:** Built with amazing open-source tools
- **Inspiration:** Helping students learn smarter, not harder

---

## 📈 Project Stats

![GitHub commit activity](https://img.shields.io/github/commit-activity/m/ai1976/recall-app)
![GitHub last commit](https://img.shields.io/github/last-commit/ai1976/recall-app)
![GitHub code size](https://img.shields.io/github/languages/code-size/ai1976/recall-app)

---

**Made with ❤️ for students who want to remember everything and ace every exam.**
