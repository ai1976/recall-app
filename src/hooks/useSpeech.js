import { useState, useEffect, useCallback, useRef } from 'react';

const VOICE_STORAGE_KEY = 'recall-tts-voice-uri';
const RATE_STORAGE_KEY = 'recall-tts-rate';

/**
 * Split text into sentences for sequential reading.
 * Prevents the Chrome/Edge 15-second TTS cutoff bug.
 */
function splitIntoChunks(text) {
  if (!text?.trim()) return [];

  // Split by sentence-ending punctuation and newlines
  const chunks = text
    .split(/(?<=[.!?\n])\s+/)
    .map(s => s.trim())
    .filter(s => s.length > 0);

  // If splitting produced nothing (e.g. text has no punctuation),
  // fall back to the original text as a single chunk
  return chunks.length > 0 ? chunks : [text.trim()];
}

export function useSpeech() {
  const [isSpeaking, setIsSpeaking] = useState(false);
  const [isSupported, setIsSupported] = useState(false);
  const [error, setError] = useState(null);
  const [voices, setVoices] = useState([]);
  const [selectedVoice, setSelectedVoice] = useState(null);
  const [rate, setRate] = useState(() => {
    const stored = localStorage.getItem(RATE_STORAGE_KEY);
    return stored ? parseFloat(stored) : 1.0;
  });

  const chunksRef = useRef([]);
  const chunkIndexRef = useRef(0);
  const isCancelledRef = useRef(false);

  // Check browser support and load voices
  useEffect(() => {
    const supported = 'speechSynthesis' in window;
    setIsSupported(supported);
    if (!supported) return;

    const loadVoices = () => {
      const availableVoices = window.speechSynthesis.getVoices();
      if (availableVoices.length === 0) return;

      setVoices(availableVoices);

      // Restore saved voice from localStorage
      const savedUri = localStorage.getItem(VOICE_STORAGE_KEY);
      if (savedUri) {
        const match = availableVoices.find(v => v.voiceURI === savedUri);
        if (match) setSelectedVoice(match);
      }
    };

    loadVoices();
    window.speechSynthesis.addEventListener('voiceschanged', loadVoices);

    return () => {
      window.speechSynthesis.removeEventListener('voiceschanged', loadVoices);
      window.speechSynthesis.cancel();
    };
  }, []);

  // Persist rate to localStorage
  useEffect(() => {
    localStorage.setItem(RATE_STORAGE_KEY, String(rate));
  }, [rate]);

  // Persist selected voice to localStorage
  const selectVoice = useCallback((voice) => {
    setSelectedVoice(voice);
    if (voice) {
      localStorage.setItem(VOICE_STORAGE_KEY, voice.voiceURI);
    } else {
      localStorage.removeItem(VOICE_STORAGE_KEY);
    }
  }, []);

  // Speak a single chunk, resolve when done
  const speakChunk = useCallback((text, voice, speechRate, lang) => {
    return new Promise((resolve, reject) => {
      const utterance = new SpeechSynthesisUtterance(text);
      utterance.rate = speechRate;
      utterance.pitch = 1.0;

      if (voice) utterance.voice = voice;
      if (lang) utterance.lang = lang;

      utterance.onend = () => resolve();
      utterance.onerror = (event) => {
        if (event.error === 'interrupted' || event.error === 'canceled') {
          reject(new Error('canceled'));
        } else {
          reject(new Error(event.error));
        }
      };

      window.speechSynthesis.speak(utterance);
    });
  }, []);

  // Main speak function with sentence chunking
  const speak = useCallback(async (text, options = {}) => {
    if (!isSupported || !text?.trim()) return;

    // Cancel any ongoing speech
    window.speechSynthesis.cancel();
    isCancelledRef.current = false;
    setError(null);

    const chunks = splitIntoChunks(text);
    chunksRef.current = chunks;
    chunkIndexRef.current = 0;

    const voice = options.voice ?? selectedVoice;
    const speechRate = options.rate ?? rate;
    const lang = options.lang ?? undefined;

    setIsSpeaking(true);

    for (let i = 0; i < chunks.length; i++) {
      if (isCancelledRef.current) break;

      chunkIndexRef.current = i;
      try {
        await speakChunk(chunks[i], voice, speechRate, lang);
      } catch (err) {
        if (err.message === 'canceled') {
          break;
        }
        setError(err.message);
        console.error('Speech error:', err.message);
        break;
      }
    }

    setIsSpeaking(false);
  }, [isSupported, rate, selectedVoice, speakChunk]);

  const stop = useCallback(() => {
    if (!isSupported) return;
    isCancelledRef.current = true;
    window.speechSynthesis.cancel();
    setIsSpeaking(false);
  }, [isSupported]);

  return {
    speak,
    stop,
    isSpeaking,
    isSupported,
    error,
    voices,
    selectedVoice,
    selectVoice,
    rate,
    setRate,
  };
}
