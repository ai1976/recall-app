import { useState } from 'react'
import Tesseract from 'tesseract.js'

export function useOCR() {
  const [isExtracting, setIsExtracting] = useState(false)
  const [progress, setProgress] = useState(0)
  const [error, setError] = useState(null)

  const extractText = async (imageFile, options = {}) => {
    const {
      language = 'eng',
      skipIfContentType = null
    } = options

    // Skip OCR for tables, diagrams, math equations
    if (skipIfContentType && ['table', 'diagram', 'math'].includes(skipIfContentType)) {
      return {
        text: '',
        confidence: 0,
        skipped: true,
        reason: `OCR skipped for ${skipIfContentType} content`
      }
    }

    setIsExtracting(true)
    setProgress(0)
    setError(null)

    try {
      const worker = await Tesseract.createWorker({
        logger: (m) => {
          if (m.status === 'recognizing text') {
            setProgress(Math.round(m.progress * 100))
          }
        }
      })

      await worker.loadLanguage(language)
      await worker.initialize(language)
      const { data } = await worker.recognize(imageFile)
      await worker.terminate()

      setIsExtracting(false)
      setProgress(100)

      return {
        text: data.text,
        confidence: data.confidence,
        skipped: false
      }
    } catch (err) {
      console.error('OCR Error:', err)
      setError(err.message)
      setIsExtracting(false)
      
      return {
        text: '',
        confidence: 0,
        skipped: false,
        error: err.message
      }
    }
  }

  return {
    extractText,
    isExtracting,
    progress,
    error
  }
}