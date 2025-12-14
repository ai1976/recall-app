import { useState, useRef } from 'react'
import { useNavigate } from 'react-router-dom'
import { Camera, Upload, X, ChevronLeft, Loader2, Image as ImageIcon } from 'lucide-react'
import { supabase } from '../lib/supabase'
import { useAuthStore, useNoteStore } from '../store'
import { CA_INTER_STRUCTURE, CONTENT_TYPES } from '../data/courses'
import imageCompression from 'browser-image-compression'
import Tesseract from 'tesseract.js'

export default function UploadNote() {
  const navigate = useNavigate()
  const { user } = useAuthStore()
  const { addNote } = useNoteStore()
  
  const fileInputRef = useRef(null)
  const cameraInputRef = useRef(null)
  
  const [step, setStep] = useState(1) // 1: Upload, 2: Details, 3: OCR
  const [imageFile, setImageFile] = useState(null)
  const [imagePreview, setImagePreview] = useState(null)
  const [uploading, setUploading] = useState(false)
  const [extractingText, setExtractingText] = useState(false)
  const [ocrProgress, setOcrProgress] = useState(0)
  
  // Form data
  const [formData, setFormData] = useState({
    title: '',
    subject: '',
    topic: '',
    contentType: 'text',
    extractedText: '',
    tags: [],
    isPublic: false,
  })
  
  const [newTag, setNewTag] = useState('')
  
  // Handle image selection
  const handleImageSelect = async (e) => {
    const file = e.target.files?.[0]
    if (!file) return
    
    try {
      // Compress image
      const options = {
        maxSizeMB: 2,
        maxWidthOrHeight: 1920,
        useWebWorker: true,
      }
      
      const compressedFile = await imageCompression(file, options)
      setImageFile(compressedFile)
      
      // Create preview
      const reader = new FileReader()
      reader.onloadend = () => {
        setImagePreview(reader.result)
        setStep(2)
      }
      reader.readAsDataURL(compressedFile)
    } catch (error) {
      console.error('Error compressing image:', error)
      alert('Failed to process image. Please try again.')
    }
  }
  
  // Extract text using OCR
  const extractText = async () => {
    if (!imagePreview || formData.contentType !== 'text') {
      handleUpload()
      return
    }
    
    setExtractingText(true)
    setStep(3)
    
    try {
      const result = await Tesseract.recognize(
        imagePreview,
        'eng',
        {
          logger: (m) => {
            if (m.status === 'recognizing text') {
              setOcrProgress(Math.round(m.progress * 100))
            }
          }
        }
      )
      
      setFormData(prev => ({ ...prev, extractedText: result.data.text }))
      setExtractingText(false)
    } catch (error) {
      console.error('OCR Error:', error)
      alert('Failed to extract text. You can still save the note.')
      setExtractingText(false)
    }
  }
  
  // Upload to Supabase
  const handleUpload = async () => {
    if (!imageFile || !formData.subject || !formData.title) {
      alert('Please fill in all required fields')
      return
    }
    
    setUploading(true)
    
    try {
      // Upload image to Supabase Storage
      const fileName = `${user.id}/${Date.now()}_${imageFile.name}`
      const { data: uploadData, error: uploadError } = await supabase.storage
        .from('notes')
        .upload(fileName, imageFile)
      
      if (uploadError) throw uploadError
      
      // Get public URL
      const { data: { publicUrl } } = supabase.storage
        .from('notes')
        .getPublicUrl(fileName)
      
      // Insert note record
      const { data: noteData, error: noteError } = await supabase
        .from('notes')
        .insert({
          user_id: user.id,
          discipline_id: CA_INTER_STRUCTURE.id,
          subject_id: formData.subject,
          topic_id: formData.topic || null,
          title: formData.title,
          content_type: formData.contentType,
          image_url: publicUrl,
          extracted_text: formData.extractedText || null,
          tags: formData.tags,
          is_public: formData.isPublic,
        })
        .select()
        .single()
      
      if (noteError) throw noteError
      
      addNote(noteData)
      alert('Note uploaded successfully!')
      navigate('/notes')
    } catch (error) {
      console.error('Upload error:', error)
      alert('Failed to upload note. Please try again.')
    } finally {
      setUploading(false)
    }
  }
  
  // Add tag
  const addTag = () => {
    if (newTag && !formData.tags.includes(newTag)) {
      setFormData(prev => ({ ...prev, tags: [...prev.tags, newTag] }))
      setNewTag('')
    }
  }
  
  // Remove tag
  const removeTag = (tagToRemove) => {
    setFormData(prev => ({
      ...prev,
      tags: prev.tags.filter(tag => tag !== tagToRemove)
    }))
  }
  
  // Get selected subject and topics
  const selectedSubject = CA_INTER_STRUCTURE.subjects.find(s => s.id === formData.subject)
  const topics = selectedSubject?.topics || []
  
  return (
    <div className="min-h-screen bg-gray-50">
      {/* Header */}
      <div className="bg-white border-b sticky top-0 z-10">
        <div className="max-w-4xl mx-auto px-4 py-4 flex items-center gap-4">
          <button
            onClick={() => navigate(-1)}
            className="p-2 hover:bg-gray-100 rounded-full"
          >
            <ChevronLeft className="w-6 h-6" />
          </button>
          <div>
            <h1 className="text-xl font-bold">Upload Note</h1>
            <p className="text-sm text-gray-600">
              Step {step} of 3: {step === 1 ? 'Select Image' : step === 2 ? 'Add Details' : 'Extract Text'}
            </p>
          </div>
        </div>
      </div>
      
      <div className="max-w-4xl mx-auto px-4 py-8">
        {/* Step 1: Upload Image */}
        {step === 1 && !imagePreview && (
          <div className="space-y-6">
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              {/* Camera Upload */}
              <button
                onClick={() => cameraInputRef.current?.click()}
                className="relative overflow-hidden rounded-xl border-2 border-dashed border-gray-300 p-12 text-center hover:border-primary-500 hover:bg-primary-50 transition"
              >
                <Camera className="mx-auto h-12 w-12 text-gray-400 mb-4" />
                <span className="text-lg font-medium text-gray-900">Take Photo</span>
                <p className="text-sm text-gray-500 mt-2">Use your camera</p>
                <input
                  ref={cameraInputRef}
                  type="file"
                  accept="image/*"
                  capture="environment"
                  onChange={handleImageSelect}
                  className="hidden"
                />
              </button>
              
              {/* File Upload */}
              <button
                onClick={() => fileInputRef.current?.click()}
                className="relative overflow-hidden rounded-xl border-2 border-dashed border-gray-300 p-12 text-center hover:border-primary-500 hover:bg-primary-50 transition"
              >
                <Upload className="mx-auto h-12 w-12 text-gray-400 mb-4" />
                <span className="text-lg font-medium text-gray-900">Upload Image</span>
                <p className="text-sm text-gray-500 mt-2">From your device</p>
                <input
                  ref={fileInputRef}
                  type="file"
                  accept="image/*"
                  onChange={handleImageSelect}
                  className="hidden"
                />
              </button>
            </div>
            
            {/* Photo Tips */}
            <div className="bg-blue-50 border border-blue-200 rounded-lg p-4">
              <h3 className="font-medium text-blue-900 mb-2">📸 Photo Tips</h3>
              <ul className="text-sm text-blue-800 space-y-1">
                <li>• Use good lighting (natural light works best)</li>
                <li>• Keep the camera straight (avoid angles)</li>
                <li>• Ensure text is clear and in focus</li>
                <li>• For tables/diagrams, select appropriate content type</li>
              </ul>
            </div>
          </div>
        )}
        
        {/* Step 2: Note Details */}
        {step === 2 && imagePreview && (
          <div className="space-y-6">
            {/* Image Preview */}
            <div className="bg-white rounded-lg border border-gray-200 p-4">
              <div className="relative">
                <img
                  src={imagePreview}
                  alt="Preview"
                  className="w-full rounded-lg"
                />
                <button
                  onClick={() => {
                    setImageFile(null)
                    setImagePreview(null)
                    setStep(1)
                  }}
                  className="absolute top-2 right-2 p-2 bg-red-500 text-white rounded-full hover:bg-red-600"
                >
                  <X className="w-4 h-4" />
                </button>
              </div>
            </div>
            
            {/* Form */}
            <div className="bg-white rounded-lg border border-gray-200 p-6 space-y-4">
              {/* Title */}
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">
                  Title *
                </label>
                <input
                  type="text"
                  value={formData.title}
                  onChange={(e) => setFormData(prev => ({ ...prev, title: e.target.value }))}
                  placeholder="e.g., Partnership Accounts Notes"
                  className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-transparent"
                  required
                />
              </div>
              
              {/* Subject */}
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">
                  Subject *
                </label>
                <select
                  value={formData.subject}
                  onChange={(e) => setFormData(prev => ({ ...prev, subject: e.target.value, topic: '' }))}
                  className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-transparent"
                  required
                >
                  <option value="">Select subject</option>
                  {CA_INTER_STRUCTURE.subjects.map(subject => (
                    <option key={subject.id} value={subject.id}>
                      {subject.name}
                    </option>
                  ))}
                </select>
              </div>
              
              {/* Topic */}
              {topics.length > 0 && (
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-2">
                    Topic (Optional)
                  </label>
                  <select
                    value={formData.topic}
                    onChange={(e) => setFormData(prev => ({ ...prev, topic: e.target.value }))}
                    className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-transparent"
                  >
                    <option value="">Select topic</option>
                    {topics.map(topic => (
                      <option key={topic.id} value={topic.id}>
                        {topic.name}
                      </option>
                    ))}
                  </select>
                </div>
              )}
              
              {/* Content Type */}
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">
                  Content Type
                </label>
                <div className="grid grid-cols-2 md:grid-cols-3 gap-2">
                  {CONTENT_TYPES.map(type => (
                    <button
                      key={type.value}
                      type="button"
                      onClick={() => setFormData(prev => ({ ...prev, contentType: type.value }))}
                      className={`px-4 py-3 rounded-lg border-2 text-left transition ${
                        formData.contentType === type.value
                          ? 'border-primary-500 bg-primary-50'
                          : 'border-gray-200 hover:border-gray-300'
                      }`}
                    >
                      <div className="text-2xl mb-1">{type.icon}</div>
                      <div className="text-sm font-medium">{type.label}</div>
                    </button>
                  ))}
                </div>
                {formData.contentType !== 'text' && (
                  <p className="text-xs text-gray-500 mt-2">
                    OCR will be skipped for this content type
                  </p>
                )}
              </div>
              
              {/* Tags */}
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">
                  Tags (Optional)
                </label>
                <div className="flex gap-2">
                  <input
                    type="text"
                    value={newTag}
                    onChange={(e) => setNewTag(e.target.value)}
                    onKeyPress={(e) => e.key === 'Enter' && (e.preventDefault(), addTag())}
                    placeholder="Add tag (e.g., important)"
                    className="flex-1 px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-transparent"
                  />
                  <button
                    type="button"
                    onClick={addTag}
                    className="px-4 py-2 bg-gray-100 hover:bg-gray-200 rounded-lg font-medium"
                  >
                    Add
                  </button>
                </div>
                {formData.tags.length > 0 && (
                  <div className="flex flex-wrap gap-2 mt-2">
                    {formData.tags.map(tag => (
                      <span
                        key={tag}
                        className="inline-flex items-center gap-1 px-3 py-1 bg-primary-100 text-primary-700 rounded-full text-sm"
                      >
                        #{tag}
                        <button
                          onClick={() => removeTag(tag)}
                          className="hover:text-primary-900"
                        >
                          <X className="w-3 h-3" />
                        </button>
                      </span>
                    ))}
                  </div>
                )}
              </div>
              
              {/* Public Toggle */}
              <div className="flex items-center justify-between">
                <div>
                  <label className="font-medium text-gray-700">Make Public</label>
                  <p className="text-sm text-gray-500">Others can view this note</p>
                </div>
                <button
                  type="button"
                  onClick={() => setFormData(prev => ({ ...prev, isPublic: !prev.isPublic }))}
                  className={`relative inline-flex h-6 w-11 items-center rounded-full transition ${
                    formData.isPublic ? 'bg-primary-600' : 'bg-gray-200'
                  }`}
                >
                  <span
                    className={`inline-block h-4 w-4 transform rounded-full bg-white transition ${
                      formData.isPublic ? 'translate-x-6' : 'translate-x-1'
                    }`}
                  />
                </button>
              </div>
            </div>
            
            {/* Actions */}
            <div className="flex gap-3">
              <button
                onClick={() => {
                  setImageFile(null)
                  setImagePreview(null)
                  setStep(1)
                }}
                className="flex-1 px-6 py-3 border border-gray-300 rounded-lg font-medium hover:bg-gray-50"
              >
                Change Photo
              </button>
              <button
                onClick={extractText}
                disabled={!formData.subject || !formData.title}
                className="flex-1 px-6 py-3 bg-primary-600 text-white rounded-lg font-medium hover:bg-primary-700 disabled:opacity-50 disabled:cursor-not-allowed"
              >
                Continue
              </button>
            </div>
          </div>
        )}
        
        {/* Step 3: OCR Extraction */}
        {step === 3 && (
          <div className="space-y-6">
            {extractingText ? (
              <div className="bg-white rounded-lg border border-gray-200 p-12 text-center">
                <Loader2 className="w-16 h-16 text-primary-600 animate-spin mx-auto mb-4" />
                <h3 className="text-lg font-medium mb-2">Extracting text...</h3>
                <p className="text-gray-600 mb-4">This may take a moment</p>
                <div className="w-full max-w-xs mx-auto bg-gray-200 rounded-full h-2">
                  <div
                    className="bg-primary-600 h-2 rounded-full transition-all duration-300"
                    style={{ width: `${ocrProgress}%` }}
                  />
                </div>
                <p className="text-sm text-gray-500 mt-2">{ocrProgress}%</p>
              </div>
            ) : (
              <>
                {/* Extracted Text */}
                <div className="bg-white rounded-lg border border-gray-200 p-6">
                  <label className="block text-sm font-medium text-gray-700 mb-2">
                    Extracted Text
                  </label>
                  <textarea
                    value={formData.extractedText}
                    onChange={(e) => setFormData(prev => ({ ...prev, extractedText: e.target.value }))}
                    placeholder="Edit extracted text or add your own notes..."
                    rows={12}
                    className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-transparent font-mono text-sm"
                  />
                  <p className="text-xs text-gray-500 mt-2">
                    You can edit the text above if OCR made any mistakes
                  </p>
                </div>
                
                {/* Final Actions */}
                <div className="flex gap-3">
                  <button
                    onClick={() => setStep(2)}
                    className="flex-1 px-6 py-3 border border-gray-300 rounded-lg font-medium hover:bg-gray-50"
                  >
                    Back
                  </button>
                  <button
                    onClick={handleUpload}
                    disabled={uploading}
                    className="flex-1 px-6 py-3 bg-primary-600 text-white rounded-lg font-medium hover:bg-primary-700 disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center gap-2"
                  >
                    {uploading ? (
                      <>
                        <Loader2 className="w-5 h-5 animate-spin" />
                        Uploading...
                      </>
                    ) : (
                      'Save Note'
                    )}
                  </button>
                </div>
              </>
            )}
          </div>
        )}
      </div>
    </div>
  )
}