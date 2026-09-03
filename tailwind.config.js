/** @type {import('tailwindcss').Config} */
export default {
    darkMode: ["class"],
    content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  theme: {
  	extend: {
  		borderRadius: {
  			lg: 'var(--radius)',
  			md: 'calc(var(--radius) - 2px)',
  			sm: 'calc(var(--radius) - 4px)',
  			// --- RevisOp two-tier radius (additive; see src/index.css --rv-radius-*) ---
  			rec: 'var(--rv-radius-rec)',   // 4px — records: rows, inputs, chips
  			obj: 'var(--rv-radius-obj)'    // 14px — study objects: card under review, grade buttons, sheets
  		},
  		fontFamily: {
  			// --- RevisOp self-hosted type system (additive; @font-face in src/index.css) ---
  			plex: 'var(--rv-font-sans)',        // UI face
  			'plex-mono': 'var(--rv-font-mono)', // numeric face (time / count)
  			literata: 'var(--rv-font-read)'     // reading bodies only — unused until 6.4
  		},
  		boxShadow: {
  			// --- RevisOp elevation (additive) ---
  			rv: 'var(--rv-shadow)',
  			'rv-bar': 'var(--rv-shadow-bar)'
  		},
  		colors: {
  			background: 'hsl(var(--background))',
  			foreground: 'hsl(var(--foreground))',
  			card: {
  				DEFAULT: 'hsl(var(--card))',
  				foreground: 'hsl(var(--card-foreground))'
  			},
  			popover: {
  				DEFAULT: 'hsl(var(--popover))',
  				foreground: 'hsl(var(--popover-foreground))'
  			},
  			primary: {
  				DEFAULT: 'hsl(var(--primary))',
  				foreground: 'hsl(var(--primary-foreground))'
  			},
  			secondary: {
  				DEFAULT: 'hsl(var(--secondary))',
  				foreground: 'hsl(var(--secondary-foreground))'
  			},
  			muted: {
  				DEFAULT: 'hsl(var(--muted))',
  				foreground: 'hsl(var(--muted-foreground))'
  			},
  			accent: {
  				DEFAULT: 'hsl(var(--accent))',
  				foreground: 'hsl(var(--accent-foreground))'
  			},
  			destructive: {
  				DEFAULT: 'hsl(var(--destructive))',
  				foreground: 'hsl(var(--destructive-foreground))'
  			},
  			border: 'hsl(var(--border))',
  			input: 'hsl(var(--input))',
  			ring: 'hsl(var(--ring))',
  			// --- RevisOp brand tokens (additive; see src/index.css) ---
  			brand: {
  				navy: {
  					DEFAULT: 'hsl(var(--brand-navy))',
  					foreground: 'hsl(var(--brand-navy-foreground))'
  				},
  				amber: {
  					DEFAULT: 'hsl(var(--brand-amber))',
  					foreground: 'hsl(var(--brand-amber-foreground))'
  				},
  				success: {
  					DEFAULT: 'hsl(var(--brand-success))',
  					foreground: 'hsl(var(--brand-success-foreground))'
  				}
  			},
  			surface: {
  				card: 'hsl(var(--surface-card))',
  				muted: 'hsl(var(--surface-muted))',
  				border: 'hsl(var(--surface-border))',
  				amber: 'hsl(var(--surface-amber))',
  				navy: 'hsl(var(--surface-navy))'
  			},
  			chart: {
  				'1': 'hsl(var(--chart-1))',
  				'2': 'hsl(var(--chart-2))',
  				'3': 'hsl(var(--chart-3))',
  				'4': 'hsl(var(--chart-4))',
  				'5': 'hsl(var(--chart-5))'
  			},
  			// --- RevisOp reskin palette (additive; full LIGHT/DARK object in src/index.css) ---
  			rv: {
  				'bg-0': 'hsl(var(--rv-bg-0))',
  				'bg-1': 'hsl(var(--rv-bg-1))',
  				'bg-2': 'hsl(var(--rv-bg-2))',
  				border: 'hsl(var(--rv-border))',
  				'border-strong': 'hsl(var(--rv-border-strong))',
  				'ink-900': 'hsl(var(--rv-ink-900))',
  				'ink-600': 'hsl(var(--rv-ink-600))',
  				'ink-400': 'hsl(var(--rv-ink-400))',
  				navy: 'hsl(var(--rv-navy))',
  				'navy-400': 'hsl(var(--rv-navy-400))',
  				'navy-100': 'hsl(var(--rv-navy-100))',
  				'navy-50': 'hsl(var(--rv-navy-50))',
  				amber: 'hsl(var(--rv-amber))',
  				'amber-ink': 'hsl(var(--rv-amber-ink))',
  				'amber-50': 'hsl(var(--rv-amber-50))',
  				'amber-edge': 'hsl(var(--rv-amber-edge))',
  				green: 'hsl(var(--rv-green))',
  				'green-50': 'hsl(var(--rv-green-50))',
  				slate: 'hsl(var(--rv-slate))',
  				'slate-50': 'hsl(var(--rv-slate-50))',
  				danger: 'hsl(var(--rv-danger))'
  			}
  		}
  	}
  },
  plugins: [require("tailwindcss-animate")],
}