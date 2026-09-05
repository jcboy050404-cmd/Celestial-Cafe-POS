// Luxury Modern Customer Mobile Ordering & Live Tracking Web App
const String customerOrderHtmlTemplate = '''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <title>Celestial Cafe — Table Self-Ordering</title>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Cinzel:wght@600;700;800;900&family=Outfit:wght@300;400;500;600;700;800&display=swap" rel="stylesheet" media="print" onload="this.media='all'">
  <style>
    /* System-font fallbacks for no-internet (local network) environments */
    @font-face {
      font-family: 'Outfit';
      src: local('-apple-system'), local('SF Pro Display'), local('Helvetica Neue'), local('Arial');
      font-weight: 100 900;
    }
    @font-face {
      font-family: 'Cinzel';
      src: local('Georgia'), local('Times New Roman'), local('Times');
      font-weight: 600 900;
    }
  </style>
  <style>
    :root {
      --bg-dark: #180e02;
      --bg-surface: #0C0A09;
      --bg-card: #14100D;
      --bg-card-elevated: #1C1612;
      --gold-primary: #D4A359;
      --gold-light: #F6EFE9;
      --gold-dark: #A37936;
      --caramel-accent: #C48248;
      --cream-light: #F6EFE9;
      --cream-soft: #D6C8BD;
      --warm-beige: #C8B29E;
      --warm-gray: #8A7B70;
      --brown-warm: #201610;
      --brown-dark: #1C120C;
      --emerald: #3DAE7A;
      --amber: #E29B38;
      --amber-brewing: #E29B38;
      --rose: #D9534F;
      --blue: #5C9DF5;
      --text-light: #F6EFE9;
      --text-muted: #D6C8BD;
      --text-subtle: #8A7B70;
      --border-subtle: rgba(250, 240, 230, 0.08);
      --border-gold: rgba(212, 163, 89, 0.35);
      --border-caramel: rgba(196, 130, 72, 0.35);
      --radius-sm: 10px;
      --radius-md: 14px;
      --radius-lg: 20px;
      --radius-xl: 24px;
      --shadow-soft: 0 4px 14px rgba(0,0,0,0.45);
      --shadow-card: 0 8px 24px rgba(0,0,0,0.55);
    }
    * {
      box-sizing: border-box;
      margin: 0;
      padding: 0;
      font-family: 'Outfit', -apple-system, BlinkMacSystemFont, 'SF Pro Display', 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
      -webkit-tap-highlight-color: transparent;
    }
    body {
      background-color: #000000;
      background-image: radial-gradient(circle at 50% 0%, rgba(196, 130, 72, 0.05) 0%, transparent 60%),
                        radial-gradient(circle at 100% 100%, rgba(30, 20, 14, 0.28) 0%, transparent 55%);
      color: var(--text-light);
      min-height: 100vh;
      display: flex;
      flex-direction: column;
      padding-bottom: 96px;
    }

    /* SVG Icon Helpers */
    .icon-svg {
      display: inline-flex;
      align-items: center;
      justify-content: center;
      vertical-align: middle;
      flex-shrink: 0;
    }

    /* Top Dark Liquid Glass Header with Scroll Transitions */
    header {
      background: linear-gradient(135deg, rgba(28, 18, 13, 0.94) 0%, rgba(18, 11, 8, 0.96) 50%, rgba(10, 6, 4, 0.98) 100%);
      backdrop-filter: blur(20px) saturate(160%);
      -webkit-backdrop-filter: blur(20px) saturate(160%);
      border-top: 1px solid rgba(255, 255, 255, 0.08);
      border-bottom: 1px solid rgba(212, 163, 89, 0.15);
      box-shadow: 
        inset 0 1px 1px rgba(255, 255, 255, 0.08),
        0 10px 32px rgba(0, 0, 0, 0.75),
        0 2px 6px rgba(0, 0, 0, 0.4);
      padding: 12px 18px;
      display: flex;
      justify-content: space-between;
      align-items: center;
      position: sticky;
      top: 0;
      z-index: 100;
      transition: padding 0.32s cubic-bezier(0.16, 1, 0.3, 1),
                  background 0.32s ease,
                  box-shadow 0.32s ease,
                  border-color 0.32s ease,
                  backdrop-filter 0.32s ease;
    }
    header::after {
      content: '';
      position: absolute;
      bottom: -1px;
      left: 0;
      right: 0;
      height: 1.5px;
      background: linear-gradient(90deg, transparent 0%, rgba(212, 163, 89, 0) 15%, rgba(212, 163, 89, 0.7) 50%, rgba(245, 215, 128, 0.9) 53%, rgba(212, 163, 89, 0.7) 56%, rgba(212, 163, 89, 0) 85%, transparent 100%);
      background-size: 200% 100%;
      opacity: 0;
      transition: opacity 0.4s ease;
      pointer-events: none;
    }
    header.scrolled {
      padding: 8px 18px;
      background: linear-gradient(135deg, rgba(20, 12, 8, 0.98) 0%, rgba(12, 7, 5, 0.99) 100%);
      backdrop-filter: blur(28px) saturate(180%);
      -webkit-backdrop-filter: blur(28px) saturate(180%);
      border-bottom-color: rgba(212, 163, 89, 0.35);
      box-shadow: 
        inset 0 1px 1px rgba(255, 255, 255, 0.12),
        0 14px 40px rgba(0, 0, 0, 0.88),
        0 3px 12px rgba(212, 163, 89, 0.16);
    }
    header.scrolled::after {
      opacity: 1;
      animation: liquidShimmer 4s ease-in-out infinite;
    }
    header .brand-logo-frame {
      transition: transform 0.32s cubic-bezier(0.16, 1, 0.3, 1);
    }
    header.scrolled .brand-logo-frame {
      transform: scale(0.92);
    }
    .brand { display: flex; align-items: center; gap: 12px; }
    .brand-logo-frame {
      height: 40px;
      width: 40px;
      border-radius: 50%;
      overflow: hidden;
      border: 1.5px solid rgba(212, 175, 55, 0.45);
      box-shadow: 0 2px 8px rgba(0,0,0,0.35);
      background: var(--bg-surface);
      display: flex;
      align-items: center;
      justify-content: center;
      flex-shrink: 0;
    }
    .brand-logo-frame img { width: 100%; height: 100%; object-fit: cover; }
    .brand-title {
      font-family: 'Cinzel', Georgia, 'Times New Roman', 'Palatino Linotype', serif;
      font-weight: 800;
      font-size: 15px;
      letter-spacing: 1.5px;
      color: #FFFFFF;
      line-height: 1.1;
      text-shadow: 0 1px 4px rgba(0,0,0,0.6);
    }
    .brand-sub {
      font-size: 10px;
      font-weight: 600;
      letter-spacing: 0.8px;
      color: #FFFFFF;
      opacity: 0.95;
      text-transform: uppercase;
    }

    .header-right {
      display: flex;
      align-items: center;
      gap: 8px;
    }
    .live-dot-pulse {
      width: 7px;
      height: 7px;
      border-radius: 50%;
      background: var(--emerald);
      box-shadow: none;
      animation: livePulse 2s infinite;
    }
    @keyframes livePulse {
      0%, 100% { opacity: 1; transform: scale(1); }
      50% { opacity: 0.4; transform: scale(0.8); }
    }
    .table-pill {
      background: rgba(196, 130, 72, 0.16);
      border: 1.2px solid var(--caramel-accent);
      color: var(--cream-light);
      padding: 6px 14px;
      border-radius: 20px;
      font-size: 12px;
      font-weight: 800;
      box-shadow: 0 2px 8px rgba(0,0,0,0.3);
      display: flex;
      align-items: center;
      gap: 6px;
      letter-spacing: 0.5px;
      cursor: pointer;
      user-select: none;
      transition: all 0.18s ease;
      font-family: inherit;
      outline: none;
    }
    .table-pill:hover {
      border-color: var(--gold-light);
      background: rgba(212, 175, 55, 0.25);
    }
    .table-pill:active { transform: scale(0.95); }
    .table-pill.takeout {
      background: rgba(226, 155, 56, 0.18);
      border-color: var(--amber);
      color: #FFC27D;
      box-shadow: 0 2px 8px rgba(0,0,0,0.3);
    }
    .table-pill.takeout:hover {
      border-color: #FFA726;
      background: rgba(255, 159, 28, 0.28);
    }
    .dining-card {
      background: #14100D;
      border: 1px solid rgba(255, 255, 255, 0.1);
      border-radius: var(--radius-lg);
      padding: 16px;
      cursor: pointer;
      display: flex;
      align-items: center;
      gap: 14px;
      transition: all 0.2s cubic-bezier(0.4, 0, 0.2, 1);
      position: relative;
      overflow: hidden;
      box-shadow: none;
    }
    .dining-card:hover {
      border-color: var(--caramel-accent);
      transform: translateY(-2px);
      box-shadow: none;
    }
    .dining-card:active { transform: scale(0.97); }
    .dining-card.selected {
      border-color: var(--caramel-accent);
      background: rgba(196, 130, 72, 0.12);
      box-shadow: none;
    }
    .dining-card.takeout-card.selected, .dining-card.takeout-card:hover {
      border-color: var(--caramel-accent);
      background: rgba(196, 130, 72, 0.12);
      box-shadow: none;
    }
    .dining-icon-box {
      width: 52px;
      height: 52px;
      border-radius: 16px;
      background: rgba(255, 255, 255, 0.06);
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 26px;
      flex-shrink: 0;
      border: 1px solid var(--border-subtle);
    }
    .takeout-card .dining-icon-box {
      background: rgba(226, 155, 56, 0.14);
      border-color: rgba(226, 155, 56, 0.4);
    }
    .order-type-tab-btn {
      flex: 1;
      padding: 11px 14px;
      border-radius: var(--radius-md);
      font-size: 13px;
      font-weight: 800;
      border: 1px solid var(--border-subtle);
      background: var(--bg-card);
      color: var(--text-muted);
      cursor: pointer;
      display: flex;
      align-items: center;
      justify-content: center;
      gap: 6px;
      transition: all 0.18s ease;
    }
    .order-type-tab-btn.active {
      border-color: var(--caramel-accent);
      background: rgba(196, 130, 72, 0.22);
      color: var(--cream-light);
      box-shadow: 0 2px 8px rgba(0,0,0,0.25);
    }
    .order-type-tab-btn.takeout.active {
      border-color: var(--amber);
      background: rgba(226, 155, 56, 0.22);
      color: #FFC27D;
      box-shadow: 0 2px 8px rgba(0,0,0,0.25);
    }

    /* Hero Spotlight Card (Tactile Micro-Skeuomorphism) */
    .hero-spotlight-card {
      position: relative;
      margin: 14px 12px 6px 12px;
      border-radius: 20px;
      overflow: hidden;
      min-height: 115px;
      display: flex;
      align-items: center;
      justify-content: space-between;
      background: var(--bg-card);
      border: 1px solid var(--border-subtle);
      box-shadow: var(--shadow-card);
      cursor: pointer;
    }
    .hero-spotlight-bg {
      position: absolute;
      inset: 0;
      background-size: cover;
      background-position: center right;
      opacity: 0.88;
      transform: scale(1.02);
      transition: transform 0.5s ease;
    }
    .hero-spotlight-card:hover .hero-spotlight-bg {
      transform: scale(1.06);
    }
    .hero-spotlight-overlay {
      position: absolute;
      inset: 0;
      background: linear-gradient(90deg, #000000FA 0%, #0C0A09E0 45%, #0C0A0944 75%, #0C0A0922 100%);
    }
    .hero-spotlight-content {
      position: relative;
      z-index: 2;
      padding: 14px 12px 14px 16px;
      flex: 1;
      min-width: 0;
    }
    .hero-spotlight-badge {
      display: inline-flex;
      align-items: center;
      gap: 5px;
      padding: 4px 10px;
      background: rgba(22, 17, 13, 0.7);
      border: 1px solid rgba(196, 130, 72, 0.45);
      border-radius: 10px;
      font-size: 9.5px;
      font-weight: 800;
      color: var(--gold-primary);
      letter-spacing: 0.8px;
      margin-bottom: 6px;
    }
    .hero-spotlight-title {
      font-size: 16.5px;
      font-weight: 800;
      color: #FFFFFF;
      letter-spacing: 0.2px;
      line-height: 1.2;
      font-family: 'Outfit', sans-serif;
    }
    .hero-spotlight-sub {
      font-size: 11.5px;
      color: var(--cream-soft);
      margin-top: 3px;
      line-height: 1.35;
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
    }
    .hero-spotlight-action {
      position: relative;
      z-index: 2;
      padding-right: 16px;
      padding-left: 8px;
      flex-shrink: 0;
    }
    .hero-spotlight-order-btn {
      background: var(--caramel-accent);
      color: #16120E;
      border: none;
      border-radius: 14px;
      padding: 9px 18px;
      font-size: 14px;
      font-weight: 800;
      font-family: 'Outfit', sans-serif;
      display: inline-flex;
      align-items: center;
      gap: 6px;
      cursor: pointer;
      box-shadow: 0 4px 14px rgba(0, 0, 0, 0.4);
      transition: all 0.15s ease;
      white-space: nowrap;
    }
    .hero-spotlight-order-btn:hover {
      background: #D9965B;
      transform: translateY(-1px);
      box-shadow: 0 4px 14px rgba(0, 0, 0, 0.4);
    }
    .hero-spotlight-order-btn:active {
      transform: scale(0.95);
    }

    /* Hero Banner Greeting */
    .hero-banner {
      padding: 14px 18px 8px 18px;
      display: flex;
      justify-content: space-between;
      align-items: flex-end;
    }
    .hero-greeting {
      font-size: 19px;
      font-weight: 800;
      color: var(--cream-light);
      font-family: 'Cinzel', Georgia, 'Times New Roman', 'Palatino Linotype', serif;
      letter-spacing: 0.5px;
    }
    .hero-sub {
      font-size: 12px;
      color: var(--warm-gray);
      margin-top: 2px;
    }

    /* Sticky Controls: Search Bar + Categories */
    .controls-wrapper {
      background: rgba(12, 10, 9, 0.95);
      backdrop-filter: blur(14px);
      -webkit-backdrop-filter: blur(14px);
      position: sticky;
      top: 65px;
      z-index: 95;
      border-bottom: 1px solid var(--border-subtle);
      padding-top: 4px;
    }

    /* Modern Search Box */
    .search-box {
      padding: 6px 18px 8px 18px;
      position: relative;
      display: flex;
      align-items: center;
    }
    .search-input {
      width: 100%;
      background: var(--bg-card);
      border: 1px solid var(--border-subtle);
      border-radius: var(--radius-md);
      padding: 10px 40px 10px 42px;
      font-size: 13.5px;
      color: var(--cream-light);
      outline: none;
      transition: all 0.2s ease;
      box-shadow: inset 0 2px 4px rgba(0,0,0,0.25);
    }
    .search-input::placeholder { color: var(--text-subtle); }
    .search-input:focus {
      border-color: var(--caramel-accent);
      background: var(--bg-card-elevated);
      box-shadow: none;
    }
    .search-icon-pos {
      position: absolute;
      left: 32px;
      color: var(--caramel-accent);
      pointer-events: none;
    }
    .clear-search-btn {
      position: absolute;
      right: 28px;
      background: rgba(255, 255, 255, 0.12);
      border: none;
      color: var(--text-muted);
      border-radius: 50%;
      width: 22px;
      height: 22px;
      font-size: 11px;
      cursor: pointer;
      display: none;
      align-items: center;
      justify-content: center;
      transition: background 0.15s;
    }
    .clear-search-btn:active { background: rgba(255,255,255,0.25); }

    /* Category Navigation Bar */
    .cat-bar {
      padding: 4px 18px 10px 18px;
      display: flex;
      gap: 8px;
      overflow-x: auto;
      scrollbar-width: none;
      -webkit-overflow-scrolling: touch;
    }
    .cat-bar::-webkit-scrollbar { display: none; }
    .cat-tab {
      background: var(--bg-card);
      border: 1px solid var(--border-subtle);
      color: var(--cream-soft);
      padding: 8px 16px;
      border-radius: 14px;
      font-size: 12.5px;
      font-weight: 600;
      cursor: pointer;
      white-space: nowrap;
      display: flex;
      align-items: center;
      gap: 6px;
      transition: all 0.18s cubic-bezier(0.4, 0, 0.2, 1);
    }
    .cat-tab:active { transform: scale(0.95); }
    .cat-tab.active {
      background: linear-gradient(135deg, #C48248 0%, #A66632 100%);
      border-color: #C48248;
      color: #110E0C;
      font-weight: 800;
      box-shadow: 0 3px 10px rgba(0,0,0,0.3);
    }

    /* Section Title & Items Count */
    .section-header {
      padding: 16px 18px 8px 18px;
      display: flex;
      justify-content: space-between;
      align-items: center;
    }
    .section-title {
      font-size: 15px;
      font-weight: 800;
      font-family: 'Cinzel', serif;
      color: var(--cream-light);
      display: flex;
      align-items: center;
      gap: 8px;
      letter-spacing: 0.5px;
    }
    .item-counter-badge {
      font-size: 11px;
      font-weight: 700;
      color: var(--cream-soft);
      background: rgba(196, 130, 72, 0.14);
      border: 1px solid rgba(196, 130, 72, 0.3);
      padding: 3px 10px;
      border-radius: 12px;
    }

    /* Menu Grid Container - GUARANTEED 2 COLUMNS ON ALL PHONES */
    .menu-container {
      padding: 8px 12px 28px 12px;
      display: grid;
      grid-template-columns: repeat(2, minmax(0, 1fr));
      gap: 12px;
    }

    @media (min-width: 600px) {
      .menu-container {
        padding: 14px 20px 32px 20px;
        grid-template-columns: repeat(auto-fill, minmax(180px, 1fr));
        gap: 16px;
      }
      .item-img-container {
        height: 140px !important;
      }
    }

    /* Item Card - Soft UI Warm Espresso Rounded Card */
    .item-card {
      background: #1D1612;
      border-radius: 20px;
      border: 1px solid var(--border-subtle);
      padding: 12px;
      display: flex;
      flex-direction: column;
      justify-content: space-between;
      box-shadow: var(--shadow-card);
      cursor: pointer;
      transition: all 0.22s cubic-bezier(0.4, 0, 0.2, 1);
      position: relative;
      overflow: hidden;
      min-width: 0;
      user-select: none;
      -webkit-user-select: none;
    }
    .item-card:hover {
      border-color: rgba(196, 130, 72, 0.45);
      transform: translateY(-3px);
      box-shadow: 0 12px 28px rgba(0, 0, 0, 0.55);
    }
    .item-card:active {
      transform: scale(0.98);
    }

    /* Inset Rounded Image */
    .item-img-container {
      width: 100%;
      height: 128px;
      border-radius: 14px;
      overflow: hidden;
      margin-bottom: 10px;
      background: #181310;
      border: 1px solid var(--border-subtle);
      position: relative;
      flex-shrink: 0;
    }
    .item-img-container img {
      width: 100%;
      height: 100%;
      object-fit: cover;
      transition: transform 0.35s ease;
      display: block;
    }
    .item-card:hover .item-img-container img {
      transform: scale(1.06);
    }
    .item-img-placeholder {
      width: 100%;
      height: 100%;
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      background: radial-gradient(circle at center, #2C1F16 0%, #181310 100%);
      color: var(--caramel-accent);
    }
    .item-img-placeholder svg { opacity: 0.75; }

    /* Card Details: Title, Category, Description */
    .item-card-info {
      display: flex;
      flex-direction: column;
      flex-grow: 1;
      margin-bottom: 8px;
    }
    .item-card-name {
      font-weight: 700;
      font-size: 16px;
      color: var(--cream-light);
      line-height: 1.22;
      margin-bottom: 3px;
      display: -webkit-box;
      -webkit-line-clamp: 2;
      -webkit-box-orient: vertical;
      overflow: hidden;
      word-break: break-word;
    }
    .item-card-cat {
      font-size: 10.5px;
      font-weight: 800;
      color: var(--warm-beige);
      text-transform: uppercase;
      letter-spacing: 0.8px;
      margin-bottom: 5px;
      display: flex;
      align-items: center;
      gap: 5px;
      flex-wrap: wrap;
    }
    .item-card-desc {
      font-size: 11.5px;
      color: var(--warm-gray);
      line-height: 1.35;
      min-height: 31px;
      max-height: 32px;
      overflow: hidden;
      text-overflow: ellipsis;
      display: -webkit-box;
      -webkit-line-clamp: 2;
      -webkit-box-orient: vertical;
      word-break: break-word;
    }

    /* Bottom Row: Gold Price on Left + Circular '+' Button on Right */
    .item-card-bottom {
      display: flex;
      align-items: center;
      justify-content: space-between;
      margin-top: auto;
      padding-top: 4px;
      width: 100%;
    }
    .item-price {
      font-size: 19px;
      font-weight: 800;
      color: #FFFFFF;
      letter-spacing: -0.3px;
      display: flex;
      align-items: baseline;
    }
    .item-price .peso-symbol {
      font-size: 17px;
      font-weight: 700;
      color: #FFFFFF;
      margin-right: 1px;
    }
    .btn-add-circle {
      width: 40px;
      height: 40px;
      min-width: 40px;
      border-radius: 50%;
      background: var(--caramel-accent);
      border: none;
      display: flex;
      align-items: center;
      justify-content: center;
      cursor: pointer;
      box-shadow: 0 4px 12px rgba(0, 0, 0, 0.35);
      transition: all 0.18s cubic-bezier(0.4, 0, 0.2, 1);
      padding: 0;
      color: #110E0C;
    }
    .btn-add-circle:hover {
      transform: scale(1.08);
      background: #D49054;
      box-shadow: 0 6px 16px rgba(0, 0, 0, 0.45);
    }
    .btn-add-circle:active {
      transform: scale(0.92);
    }
    .btn-add-circle svg {
      width: 18px;
      height: 18px;
      stroke: #110E0C;
      stroke-width: 2.8;
    }

    /* Sold Out States */
    .item-card.sold-out {
      opacity: 0.6;
    }
    .item-card.sold-out .btn-add-circle {
      background: #281F1A;
      box-shadow: none;
      cursor: not-allowed;
    }
    .item-card.sold-out .btn-add-circle svg {
      stroke: var(--warm-gray);
    }

    /* Floating Cart Tray Bar */
    .cart-bar {
      position: fixed;
      bottom: 14px;
      left: 16px;
      right: 16px;
      background: rgba(12, 10, 9, 0.96);
      backdrop-filter: blur(18px);
      -webkit-backdrop-filter: blur(18px);
      border: 1px solid var(--border-subtle);
      border-radius: var(--radius-xl);
      padding: 12px 18px;
      display: flex;
      justify-content: space-between;
      align-items: center;
      z-index: 100;
      box-shadow: 0 10px 30px rgba(0,0,0,0.7);
      animation: slideUpTray 0.3s cubic-bezier(0.4, 0, 0.2, 1);
    }
    @keyframes slideUpTray {
      from { transform: translateY(100px); opacity: 0; }
      to { transform: translateY(0); opacity: 1; }
    }
    .cart-summary { display: flex; flex-direction: column; }
    .cart-count { font-size: 11.5px; color: var(--warm-beige); font-weight: 600; letter-spacing: 0.4px; }
    .cart-total { font-size: 20px; font-weight: 800; color: #FFFFFF; letter-spacing: 0.5px; }
    .btn-view-tray {
      background: var(--caramel-accent);
      color: #110E0C;
      border: none;
      border-radius: 14px;
      padding: 12px 22px;
      font-size: 14px;
      font-weight: 800;
      cursor: pointer;
      display: flex;
      align-items: center;
      gap: 8px;
      box-shadow: 0 4px 14px rgba(0, 0, 0, 0.35);
      transition: all 0.15s ease;
    }
    .btn-view-tray:active { transform: scale(0.96); }
    #btnSendOrder:active { transform: scale(0.98); }
    #btnSendOrder:disabled { opacity: 0.65; cursor: not-allowed; transform: none; }

    /* Modal Overlay & Bottom Sheet */
    .modal-overlay {
      position: fixed;
      top: 0; left: 0; right: 0; bottom: 0;
      background: rgba(0,0,0,0.80);
      backdrop-filter: blur(8px);
      -webkit-backdrop-filter: blur(8px);
      z-index: 200;
      display: none;
      align-items: flex-end;
      animation: fadeInModal 0.2s ease-out;
    }
    @keyframes fadeInModal {
      from { opacity: 0; }
      to { opacity: 1; }
    }
    .modal-content {
      background: var(--bg-surface);
      border-radius: 28px 28px 0 0;
      border-top: 1px solid var(--border-subtle);
      width: 100%;
      max-height: 90vh;
      overflow-y: auto;
      padding: 20px 20px 32px 20px;
      box-shadow: 0 -10px 40px rgba(0,0,0,0.85);
      animation: slideUpSheet 0.25s cubic-bezier(0.4, 0, 0.2, 1);
    }
    @keyframes slideUpSheet {
      from { transform: translateY(100%); }
      to { transform: translateY(0); }
    }
    .modal-drag-pill {
      width: 44px;
      height: 4px;
      border-radius: 4px;
      background: rgba(255, 255, 255, 0.18);
      margin: 0 auto 16px auto;
    }

    .modal-title { font-size: 19px; font-weight: 800; font-family: 'Cinzel', serif; color: var(--cream-light); }
    .modal-desc { font-size: 12px; color: var(--cream-soft); margin-top: 4px; margin-bottom: 16px; line-height: 1.4; }
    
    .opt-group-title {
      font-size: 12px;
      font-weight: 700;
      color: var(--cream-light);
      text-transform: uppercase;
      margin-top: 16px;
      margin-bottom: 8px;
      letter-spacing: 0.8px;
      display: flex;
      align-items: center;
      gap: 6px;
    }
    .opt-grid { display: flex; flex-wrap: wrap; gap: 8px; margin-bottom: 6px; }
    .opt-chip {
      background: var(--bg-card);
      border: 1px solid var(--border-subtle);
      color: var(--cream-soft);
      padding: 9px 15px;
      border-radius: var(--radius-md);
      font-size: 13px;
      font-weight: 600;
      cursor: pointer;
      display: flex;
      align-items: center;
      gap: 6px;
      transition: all 0.15s ease;
    }
    .opt-chip.selected {
      background: rgba(196, 130, 72, 0.22);
      border-color: var(--caramel-accent);
      color: var(--cream-light);
      font-weight: 700;
      box-shadow: 0 2px 8px rgba(0, 0, 0, 0.25);
    }

    /* ── Customer Experience & Feedback Rating Styling ── */
    .cust-fb-chip {
      background: rgba(255, 255, 255, 0.05);
      border: 1px solid rgba(255, 255, 255, 0.15);
      color: #D4C5B9;
      border-radius: 18px;
      padding: 6px 12px;
      font-size: 11.5px;
      font-weight: 600;
      cursor: pointer;
      transition: all 0.15s ease;
      user-select: none;
    }
    .cust-fb-chip:hover {
      border-color: var(--caramel-accent);
      color: #FFFFFF;
      background: rgba(255, 255, 255, 0.08);
    }
    .cust-fb-chip.active {
      background: rgba(196, 130, 72, 0.2);
      border-color: var(--caramel-accent);
      color: #FFFFFF;
      font-weight: 700;
    }
    .cust-star-btn {
      background: transparent;
      border: none;
      padding: 3px;
      cursor: pointer;
      transition: transform 0.15s cubic-bezier(0.175, 0.885, 0.32, 1.275);
    }
    .cust-star-btn:hover {
      transform: scale(1.22);
    }
    .cust-star-svg {
      width: 32px;
      height: 32px;
      transition: fill 0.15s ease, stroke 0.15s ease;
    }

    /* ── Customization Dialog / Modal (Showcase Layout) ── */
    #customModal {
      align-items: center;
      justify-content: center;
      padding: 16px;
    }
    @media (max-width: 600px) {
      #customModal {
        align-items: flex-end;
        padding: 0;
      }
    }
    .custom-dialog-card {
      background: #0C0A09;
      border: 1px solid var(--border-subtle);
      border-radius: 24px;
      width: 100%;
      max-width: 440px;
      max-height: 90vh;
      display: flex;
      flex-direction: column;
      box-shadow: 0 20px 60px rgba(0, 0, 0, 0.95);
      overflow: hidden;
      position: relative;
      animation: popIn 0.22s cubic-bezier(0.18, 0.89, 0.32, 1.28);
    }
    @media (max-width: 600px) {
      .custom-dialog-card {
        border-radius: 24px 24px 0 0;
        max-height: 94vh;
      }
    }

    .cust-dlg-floating-close {
      position: absolute;
      top: 14px;
      right: 14px;
      width: 32px;
      height: 32px;
      border-radius: 50%;
      background: rgba(255, 255, 255, 0.10);
      border: 1px solid var(--border-subtle);
      color: var(--cream-light);
      font-size: 14px;
      cursor: pointer;
      display: flex;
      align-items: center;
      justify-content: center;
      z-index: 10;
      transition: all 0.15s ease;
    }
    .cust-dlg-floating-close:hover {
      background: rgba(255, 255, 255, 0.20);
    }

    .cust-dlg-body {
      padding: 16px 18px;
      overflow-y: auto;
      -webkit-overflow-scrolling: touch;
      flex: 1;
      display: flex;
      flex-direction: column;
      gap: 14px;
    }

    /* ── Top Product Showcase Card (Soft UI Minimalist) ── */
    .cust-showcase-card {
      background: #16120E;
      border: 1px solid rgba(255, 255, 255, 0.08);
      border-radius: 20px;
      padding: 14px;
      display: flex;
      flex-direction: column;
      box-shadow: var(--shadow-soft);
    }
    .cust-showcase-img-box {
      width: 100%;
      height: 155px;
      border-radius: 14px;
      overflow: hidden;
      display: flex;
      align-items: center;
      justify-content: center;
      background: #140E0C;
      border: 1px solid var(--border-subtle);
      margin-bottom: 12px;
      position: relative;
    }
    .cust-showcase-img-box img {
      width: 100%;
      height: 100%;
      object-fit: cover;
      display: block;
    }
    .cust-img-close-btn {
      position: absolute;
      top: 10px;
      right: 10px;
      width: 32px;
      height: 32px;
      border-radius: 50%;
      background: rgba(0, 0, 0, 0.55);
      backdrop-filter: blur(8px);
      -webkit-backdrop-filter: blur(8px);
      border: 1px solid rgba(255, 255, 255, 0.18);
      color: #FFFFFF;
      font-size: 14px;
      font-weight: 700;
      cursor: pointer;
      display: flex;
      align-items: center;
      justify-content: center;
      z-index: 10;
      transition: all 0.15s ease;
    }
    .cust-img-close-btn:hover {
      background: rgba(0, 0, 0, 0.85);
      transform: scale(1.05);
    }
    .cust-img-close-btn:active {
      transform: scale(0.92);
    }
    .cust-showcase-info {
      display: flex;
      flex-direction: column;
      gap: 2px;
    }
    .cust-showcase-name {
      font-size: 20px;
      font-weight: 800;
      color: #FFFFFF;
      font-family: 'Outfit', sans-serif;
      line-height: 1.25;
      letter-spacing: 0.2px;
    }
    .cust-showcase-price {
      font-size: 17.5px;
      font-weight: 800;
      color: #FFFFFF;
      font-family: 'Outfit', sans-serif;
      margin-top: 3px;
    }
    .cust-showcase-desc {
      font-size: 12px;
      color: var(--cream-soft);
      line-height: 1.45;
      margin-top: 5px;
      font-family: 'Outfit', sans-serif;
      opacity: 0.88;
    }

    /* ── Group Header (Tactile Icon + Title + Badge) ── */
    .cust-group-section {
      margin-top: 14px;
      margin-bottom: 6px;
    }
    .cust-group-header {
      display: flex;
      align-items: center;
      justify-content: space-between;
      margin-bottom: 10px;
    }
    .cust-group-header-left {
      display: flex;
      align-items: center;
      gap: 8px;
    }
    .cust-group-icon-box {
      width: 24px;
      height: 24px;
      border-radius: 7px;
      background: rgba(196, 130, 72, 0.18);
      display: flex;
      align-items: center;
      justify-content: center;
      flex-shrink: 0;
    }
    .cust-group-title {
      font-size: 14.5px;
      font-weight: 800;
      color: #FFFFFF;
      font-family: 'Outfit', sans-serif;
      letter-spacing: 0.2px;
    }
    .cust-group-badge {
      display: inline-flex;
      align-items: center;
      gap: 4px;
      padding: 3px 8px;
      border-radius: 6px;
      font-size: 9.5px;
      font-weight: 800;
      letter-spacing: 0.5px;
      text-transform: uppercase;
      font-family: 'Outfit', sans-serif;
    }
    .cust-group-badge.required {
      background: rgba(196, 130, 72, 0.16);
      border: 0.8px solid rgba(196, 130, 72, 0.45);
      color: #F6EFE9;
    }
    .cust-group-badge.optional {
      background: rgba(255, 255, 255, 0.05);
      border: 0.8px solid rgba(255, 255, 255, 0.1);
      color: #8A7B70;
    }
    .cust-badge-dot {
      width: 5px;
      height: 5px;
      border-radius: 50%;
      background: #C48248;
      display: inline-block;
    }

    /* ── Pill Buttons with Radio Indicator (Temperature & Sweetness) ── */
    .cust-pill-row {
      display: flex;
      gap: 10px;
      width: 100%;
    }
    .cust-pill-row .cust-pill-btn {
      flex: 1;
      min-width: 0;
    }
    .cust-pill-grid {
      display: grid;
      grid-template-columns: repeat(2, 1fr);
      gap: 10px;
      width: 100%;
    }
    .cust-pill-btn {
      background: #16120E;
      border: 1px solid rgba(255, 255, 255, 0.12);
      border-radius: 14px;
      padding: 10px 14px;
      display: flex;
      align-items: center;
      gap: 8px;
      cursor: pointer;
      user-select: none;
      transition: all 0.15s ease;
      font-family: 'Outfit', sans-serif;
      text-align: left;
    }
    .cust-pill-btn:hover {
      background: #1F1814;
      border-color: rgba(196, 130, 72, 0.35);
    }
    .cust-pill-btn:active {
      transform: scale(0.98);
    }
    .cust-pill-btn.selected {
      background: rgba(196, 130, 72, 0.12);
      border: 1.6px solid #C48248;
    }
    .cust-radio-ring {
      width: 17px;
      height: 17px;
      border-radius: 50%;
      border: 1.5px solid rgba(255, 255, 255, 0.35);
      display: flex;
      align-items: center;
      justify-content: center;
      flex-shrink: 0;
      transition: all 0.15s ease;
    }
    .cust-pill-btn.selected .cust-radio-ring {
      border-color: #C48248;
    }
    .cust-radio-dot {
      width: 7px;
      height: 7px;
      border-radius: 50%;
      background: #C48248;
      display: none;
    }
    .cust-pill-btn.selected .cust-radio-dot {
      display: block;
    }
    .cust-pill-label {
      font-size: 13.5px;
      font-weight: 600;
      color: #D6C8BD;
      line-height: 1.25;
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
    }
    .cust-pill-btn.selected .cust-pill-label {
      color: #FFFFFF;
      font-weight: 800;
    }
    .cust-pill-extra {
      font-size: 11.5px;
      color: var(--caramel-accent);
      margin-left: auto;
      font-weight: 700;
    }

    /* ── Add-ons & Extras Rows ── */
    .cust-addon-list {
      display: flex;
      flex-direction: column;
      gap: 8px;
      width: 100%;
    }
    .cust-addon-row {
      background: #16120E;
      border: 1px solid rgba(255, 255, 255, 0.1);
      border-radius: 14px;
      padding: 12px 14px;
      display: flex;
      align-items: center;
      justify-content: space-between;
      cursor: pointer;
      transition: all 0.15s ease;
      user-select: none;
    }
    .cust-addon-row:hover {
      background: #1F1814;
      border-color: rgba(196, 130, 72, 0.35);
    }
    .cust-addon-row:active {
      transform: scale(0.99);
    }
    .cust-addon-row.selected {
      background: rgba(196, 130, 72, 0.12);
      border: 1.5px solid var(--caramel-accent);
    }
    .cust-addon-row-left {
      display: flex;
      align-items: center;
      gap: 10px;
      color: #FFFFFF;
      font-size: 14px;
      font-weight: 700;
      font-family: 'Outfit', sans-serif;
    }
    .cust-addon-circle {
      width: 22px;
      height: 22px;
      border-radius: 50%;
      border: 1.4px solid rgba(255, 255, 255, 0.25);
      display: flex;
      align-items: center;
      justify-content: center;
      flex-shrink: 0;
      font-size: 13px;
      color: rgba(255, 255, 255, 0.7);
      transition: all 0.15s ease;
    }
    .cust-addon-row.selected .cust-addon-circle {
      background: var(--caramel-accent);
      border-color: var(--caramel-accent);
      color: #16120E;
      font-weight: 900;
    }
    .cust-addon-row-right {
      color: #8A7B70;
      font-size: 13.5px;
      font-weight: 700;
      font-family: 'Outfit', sans-serif;
    }
    .cust-addon-row.selected .cust-addon-row-right {
      color: var(--cream-light);
    }

    /* ── Bottom Sticky Bar ── */
    .cust-dlg-footer {
      padding: 12px 18px max(18px, env(safe-area-inset-bottom, 18px)) 18px;
      background: #0C0A09;
      border-top: 1px solid var(--border-subtle);
      display: flex;
      align-items: center;
      gap: 12px;
      flex-shrink: 0;
    }
    .cust-stepper {
      height: 46px;
      border: 1px solid var(--border-subtle);
      border-radius: 14px;
      background: #16120E;
      display: flex;
      align-items: center;
      padding: 0 6px;
      flex-shrink: 0;
    }
    .cust-stepper-btn {
      width: 32px;
      height: 36px;
      background: none;
      border: none;
      color: var(--caramel-accent);
      font-size: 20px;
      font-weight: 700;
      cursor: pointer;
      display: flex;
      align-items: center;
      justify-content: center;
      transition: transform 0.1s ease;
    }
    .cust-stepper-btn:active {
      transform: scale(0.85);
    }
    .cust-stepper-val {
      font-size: 16px;
      font-weight: 800;
      font-family: 'Outfit', sans-serif;
      color: var(--cream-light);
      min-width: 22px;
      text-align: center;
    }
    .cust-add-btn {
      flex: 1;
      height: 46px;
      background: var(--caramel-accent);
      color: #110E0C;
      border: none;
      border-radius: 16px;
      font-size: 15px;
      font-weight: 800;
      font-family: 'Outfit', sans-serif;
      cursor: pointer;
      display: flex;
      align-items: center;
      justify-content: center;
      gap: 8px;
      box-shadow: 0 4px 14px rgba(0, 0, 0, 0.3);
      transition: all 0.15s ease;
    }
    .cust-add-btn:active {
      transform: scale(0.96);
    }

    /* Quantity Stepper Control in Customization Modal */
    .qty-stepper-row {
      display: flex;
      justify-content: space-between;
      align-items: center;
      background: var(--bg-card);
      border: 1px solid var(--border-subtle);
      border-radius: var(--radius-md);
      padding: 10px 14px;
      margin-top: 14px;
      margin-bottom: 14px;
    }
    .qty-controls {
      display: flex;
      align-items: center;
      gap: 12px;
    }
    .btn-qty {
      width: 32px;
      height: 32px;
      border-radius: 8px;
      background: rgba(255, 255, 255, 0.08);
      border: 1px solid var(--border-subtle);
      color: var(--text-light);
      font-weight: bold;
      font-size: 16px;
      cursor: pointer;
      display: flex;
      align-items: center;
      justify-content: center;
      transition: all 0.15s;
    }
    .btn-qty:active { background: var(--caramel-accent); color: #110E0C; }
    .qty-display { font-size: 16px; font-weight: 800; color: var(--gold-primary); min-width: 24px; text-align: center; }

    /* =========================================================
       AUTHENTIC POS THERMAL RECEIPT PRINTER UI & ANIMATION
       ========================================================= */
    .printer-housing {
      max-width: 390px;
      margin: 14px auto 28px auto;
      position: relative;
      text-align: center;
    }
    .printer-bezel {
      width: 100%;
      max-width: 370px;
      margin: 0 auto;
      padding: 9px 16px;
      background: linear-gradient(180deg, #FFFFFF 0%, #E3E5E9 25%, #C8CDD4 60%, #A2A8B2 100%);
      border-radius: 24px;
      border: 1.5px solid #F8F9FA;
      box-shadow: 
        0 8px 24px rgba(0, 0, 0, 0.55),
        0 2px 6px rgba(0, 0, 0, 0.3),
        inset 0 1.5px 2px rgba(255, 255, 255, 0.95),
        inset 0 -1.5px 3px rgba(0, 0, 0, 0.3);
      position: relative;
      z-index: 20;
    }
    .printer-slot-mouth {
      height: 15px;
      background: #08080A;
      border-radius: 10px;
      box-shadow: 
        inset 0 5px 9px rgba(0, 0, 0, 0.98),
        inset 0 -1px 2px rgba(255, 255, 255, 0.15);
      border: 1.2px solid #1E2024;
    }
    .printer-feed-viewport {
      max-width: 336px;
      margin: -6px auto 0 auto;
      overflow: hidden;
      position: relative;
      z-index: 10;
      padding-bottom: 8px;
    }
    .thermal-receipt-paper {
      background: #FFFFFF;
      box-shadow: 
        0 16px 40px rgba(0, 0, 0, 0.45),
        0 4px 12px rgba(0, 0, 0, 0.2);
      margin: 0 auto;
      position: relative;
      color: #1A120C;
      font-family: 'Courier New', Courier, monospace, 'Outfit', sans-serif;
      transform-origin: top center;
    }
    .thermal-receipt-paper.printing-feed-anim {
      animation: printFeedDown 2s cubic-bezier(0.15, 0.85, 0.35, 1) forwards;
    }
    @keyframes printFeedDown {
      0% {
        transform: translateY(-100%);
        opacity: 0;
      }
      10% {
        transform: translateY(-82%);
        opacity: 1;
      }
      28% {
        transform: translateY(-62%);
      }
      50% {
        transform: translateY(-38%);
      }
      72% {
        transform: translateY(-18%);
      }
      88% {
        transform: translateY(-6%);
      }
      100% {
        transform: translateY(0%);
        opacity: 1;
      }
    }

    .receipt-inner-body {
      padding: 16px 18px 8px 18px;
      text-align: center;
    }
    .receipt-dash-rule {
      color: #7D7571;
      font-size: 11px;
      letter-spacing: 2px;
      overflow: hidden;
      white-space: nowrap;
      user-select: none;
      margin: 6px 0;
      font-family: 'Courier New', Courier, monospace;
      font-weight: 700;
    }
    .receipt-main-title {
      font-family: 'Cinzel', 'Outfit', sans-serif;
      font-size: 22px;
      font-weight: 900;
      letter-spacing: 6px;
      color: #1A120C;
      margin: 4px 0;
      text-transform: uppercase;
    }
    .receipt-brand-title {
      font-family: 'Cinzel', serif;
      font-size: 13.5px;
      font-weight: 800;
      letter-spacing: 2px;
      color: #3D2314;
      margin-top: 4px;
    }
    .receipt-brand-tagline {
      font-size: 10px;
      letter-spacing: 1px;
      color: #8C5B2C;
      font-weight: 700;
      text-transform: uppercase;
      margin-bottom: 8px;
    }
    .receipt-wifi-pill {
      display: inline-flex;
      align-items: center;
      gap: 6px;
      background: #F0FDF4;
      border: 1px solid #BBF7D0;
      color: #15803D;
      border-radius: 14px;
      padding: 3px 10px;
      font-size: 10px;
      font-weight: 700;
      margin-bottom: 10px;
      font-family: 'Outfit', sans-serif;
    }
    .receipt-order-hero {
      margin: 6px 0 10px 0;
    }
    .receipt-order-label {
      font-size: 11px;
      font-weight: 800;
      letter-spacing: 2px;
      color: #8C5B2C;
      text-transform: uppercase;
    }
    .receipt-order-num {
      font-family: 'Cinzel', serif;
      font-size: 56px;
      line-height: 1.05;
      font-weight: 900;
      color: #1A120C;
      margin: 2px 0 4px 0;
      letter-spacing: 2px;
    }
    .receipt-table-pill {
      display: inline-block;
      font-size: 12px;
      font-weight: 700;
      color: #4A3B32;
      background: #F4EFEB;
      border: 1px solid #E2DAD2;
      border-radius: 12px;
      padding: 3px 12px;
      font-family: 'Outfit', sans-serif;
    }

    /* Instruction Banner Card - Authentic Ticket Seal / Stamp (No Neon Effects) */
    .tracker-instruction-card {
      background: #FAF6F0;
      border: 1.5px dashed #D4A373;
      border-radius: 14px;
      padding: 12px 14px;
      margin: 12px 0;
      text-align: center;
      position: relative;
      box-shadow: none;
      transition: all 0.3s ease;
      font-family: 'Outfit', sans-serif;
    }
    .tracker-instruction-card.ticket-stamp-confirmed {
      border: 1.5px solid #22C55E;
      background: #F0FDF4;
      box-shadow: none;
    }
    .tracker-instruction-card.ticket-stamp-brewing {
      border: 1.5px solid #F59E0B;
      background: #FFFBEB;
      box-shadow: none;
    }
    .tracker-instruction-card.ticket-stamp-ready {
      border: 2px solid #16A34A;
      background: #F0FDF4;
      box-shadow: none;
    }
    .tracker-instruction-title {
      font-family: 'Cinzel', serif;
      font-size: 13.5px;
      font-weight: 800;
      color: #1A120C;
      letter-spacing: 0.8px;
      line-height: 1.35;
      text-transform: uppercase;
    }
    .tracker-instruction-card.ticket-stamp-confirmed .tracker-instruction-title {
      color: #15803D;
    }
    .tracker-instruction-card.ticket-stamp-brewing .tracker-instruction-title {
      color: #B45309;
    }
    .tracker-instruction-card.ticket-stamp-ready .tracker-instruction-title {
      color: #15803D;
    }
    .tracker-instruction-status {
      font-size: 12px;
      color: #8C5B2C;
      margin-top: 4px;
      font-weight: 600;
    }
    .tracker-instruction-card.ticket-stamp-confirmed .tracker-instruction-status {
      color: #166534;
    }
    .tracker-instruction-card.ticket-stamp-brewing .tracker-instruction-status {
      color: #92400E;
    }
    .tracker-instruction-card.ticket-stamp-ready .tracker-instruction-status {
      color: #166534;
    }

    /* Receipt Item Rows (Matching reference image) */
    .receipt-items-table {
      margin: 8px 0;
      text-align: left;
      font-family: 'Courier New', Courier, monospace;
      font-size: 12px;
    }
    .receipt-item-line {
      display: flex;
      justify-content: space-between;
      align-items: baseline;
      padding: 3px 0;
      color: #1A120C;
    }
    .receipt-item-name {
      font-weight: 600;
      flex: 1;
      padding-right: 8px;
      overflow: hidden;
      text-overflow: ellipsis;
      white-space: nowrap;
    }
    .receipt-item-price {
      font-weight: 700;
      white-space: nowrap;
    }

    /* Receipt Financial Breakdown */
    .receipt-total-section {
      font-family: 'Courier New', Courier, monospace;
      margin: 8px 0;
    }
    .receipt-total-row {
      display: flex;
      justify-content: space-between;
      align-items: baseline;
      font-size: 14.5px;
      font-weight: 900;
      color: #1A120C;
      padding: 4px 0;
    }
    .receipt-total-val {
      font-family: 'Outfit', sans-serif;
      font-size: 17px;
      font-weight: 900;
    }
    .receipt-sub-row {
      display: flex;
      justify-content: space-between;
      font-size: 12px;
      color: #5C4A3E;
      padding: 2px 0;
    }

    /* THANK YOU */
    .receipt-thank-you {
      font-family: 'Cinzel', 'Outfit', sans-serif;
      font-size: 20px;
      font-weight: 900;
      letter-spacing: 4px;
      color: #1A120C;
      margin-top: 4px;
    }
    .receipt-thank-sub {
      font-size: 11px;
      color: #7D7571;
      font-weight: 600;
      margin-top: 2px;
      margin-bottom: 10px;
      font-family: 'Outfit', sans-serif;
    }

    /* QR Code Box */
    .receipt-qr-section {
      text-align: center;
      margin: 8px 0 10px 0;
    }
    .receipt-qr-frame {
      display: inline-flex;
      align-items: center;
      justify-content: center;
      padding: 10px;
      background: #FFFFFF;
      border: 1.5px solid #1A120C;
      border-radius: 12px;
      box-shadow: 0 4px 12px rgba(0, 0, 0, 0.08);
      margin: 0 auto;
    }
    .receipt-qr-frame img,
    .receipt-qr-frame svg {
      display: block;
      width: 175px;
      height: 175px;
      margin: 0 auto;
    }
    .receipt-qr-caption {
      font-size: 10.5px;
      color: #6E5D53;
      font-weight: 700;
      margin-top: 6px;
      letter-spacing: 0.5px;
      font-family: 'Outfit', sans-serif;
    }
    .receipt-serial-code {
      font-family: 'Cinzel', monospace, serif;
      font-size: 11px;
      font-weight: 700;
      letter-spacing: 2px;
      color: #8C5B2C;
      margin-top: 4px;
    }

    /* Serrated Receipt / Ticket Sawtooth Bottom */
    .ticket-sawtooth-bottom {
      height: 12px;
      overflow: hidden;
      margin-top: -1px;
      background: #FFFFFF;
    }

    /* Collapsible Details Toggle & Drawer (Reference Design) */
    .tracker-details-toggle {
      display: inline-flex;
      align-items: center;
      justify-content: center;
      gap: 6px;
      color: #C48248;
      font-size: 13.5px;
      font-weight: 700;
      cursor: pointer;
      margin: 20px auto 14px auto;
      user-select: none;
      transition: all 0.2s;
    }
    .tracker-details-toggle:hover {
      color: #D4AF37;
    }
    .tracker-chevron {
      display: inline-block;
      font-size: 13px;
      transition: transform 0.25s ease;
    }
    .tracker-chevron.open {
      transform: rotate(180deg);
    }
    .tracker-details-drawer {
      background: rgba(0, 0, 0, 0.35);
      border: 1px solid rgba(255, 255, 255, 0.1);
      border-radius: 14px;
      padding: 12px 16px;
      margin-bottom: 16px;
      text-align: left;
      max-height: 240px;
      overflow-y: auto;
    }

    /* Notice Banners (Fallback Compatibility) */
    .tracker-notice-box {
      border-radius: 20px;
      padding: 18px 16px;
      margin-top: 14px;
      text-align: center;
      position: relative;
      overflow: hidden;
      backdrop-filter: blur(8px);
    }
    .notice-icon-circle {
      width: 44px;
      height: 44px;
      border-radius: 50%;
      display: flex;
      align-items: center;
      justify-content: center;
      margin: 0 auto 10px auto;
      transition: all 0.3s ease;
    }
    .notice-icon-emerald {
      background: rgba(61, 174, 122, 0.18);
      border: 1.5px solid var(--emerald);
      color: var(--emerald);
    }
    .notice-icon-amber {
      background: rgba(226, 155, 56, 0.18);
      border: 1.5px solid var(--amber);
      color: #FFC27D;
    }
    .notice-icon-gold {
      background: rgba(196, 130, 72, 0.18);
      border: 1.5px solid var(--caramel-accent);
      color: var(--cream-light);
    }
    .notice-banner-ready {
      background: rgba(61, 174, 122, 0.14);
      border: 1.5px solid var(--emerald);
      box-shadow: 0 4px 18px rgba(0,0,0,0.35);
    }
    .notice-banner-brewing {
      background: rgba(226, 155, 56, 0.14);
      border: 1.5px solid var(--amber);
      box-shadow: 0 4px 18px rgba(0,0,0,0.35);
    }
    .notice-banner-confirmed {
      background: rgba(61, 174, 122, 0.12);
      border: 1.5px solid var(--emerald);
    }
    .notice-banner-pending {
      background: rgba(196, 130, 72, 0.12);
      border: 1.5px solid var(--caramel-accent);
    }

    /* Milestone Stepper */
    .status-steps {
      display: flex;
      justify-content: space-between;
      margin-top: 18px;
      margin-bottom: 18px;
      position: relative;
    }
    .status-steps::before {
      content: '';
      position: absolute;
      top: 21px;
      left: 18%;
      right: 18%;
      height: 2px;
      background: #E2DBD4;
      z-index: 1;
    }
    .status-step {
      display: flex;
      flex-direction: column;
      align-items: center;
      gap: 8px;
      z-index: 2;
      flex: 1;
    }
    .step-dot {
      width: 42px;
      height: 42px;
      border-radius: 50%;
      background: #F3EFEA;
      border: 1.5px solid #D8CEC4;
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 14px;
      font-weight: 800;
      color: #9C8E84;
      transition: all 0.3s ease;
      box-shadow: none;
    }
    .step-label {
      font-size: 12px;
      font-weight: 700;
      color: #6E5D53;
      transition: color 0.3s ease;
      text-align: center;
      line-height: 1.25;
    }
    .status-step.active .step-dot {
      background: #C48248;
      border-color: #C48248;
      color: #FFFFFF;
      font-size: 15px;
      font-weight: 900;
      box-shadow: none;
      transform: none;
    }
    .status-step.active .step-label {
      color: #1A120C;
      font-weight: 800;
    }
    .status-step.completed .step-dot {
      background: #16A34A;
      border-color: #16A34A;
      color: #FFFFFF;
      font-size: 0;
      box-shadow: none;
    }
    .status-step.completed .step-dot::after {
      content: '✓';
      font-size: 16px;
      font-weight: 900;
      color: #FFFFFF;
    }
    .status-step.completed .step-label {
      color: #15803D;
      font-weight: 700;
    }

    /* Estimated Waiting Time */
    .tracker-wait-time-row {
      font-size: 13.5px;
      color: #5C4A3E;
      margin-top: 18px;
      text-align: center;
      font-weight: 600;
    }
    .wait-time-highlight {
      color: #8C5B2C;
      font-weight: 800;
    }

    /* Live Kitchen Queue Action Button */
    .btn-kitchen-queue {
      width: 100%;
      background: #F7F4EF;
      border: 1px solid #E2DBD4;
      color: #2C1810;
      border-radius: 16px;
      padding: 13px 16px;
      font-weight: 800;
      font-size: 13.5px;
      cursor: pointer;
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 8px;
      box-shadow: none;
      transition: all 0.2s ease;
    }
    .btn-kitchen-queue:hover {
      border-color: #C48248;
      background: #F2ECE4;
    }
    .btn-kitchen-queue:active {
      transform: scale(0.98);
    }
    .queue-live-dot {
      width: 8px;
      height: 8px;
      border-radius: 50%;
      background: #C48248;
      display: inline-block;
      box-shadow: none;
    }
    .queue-badge-pill {
      background: #EBE5DC;
      border: 1px solid #DCD3C7;
      color: #5C4A3E;
      font-size: 11px;
      padding: 4px 10px;
      border-radius: 12px;
      font-weight: 800;
      box-shadow: none;
    }

    .btn-view-receipt {
      width: 100%;
      background: #F0FDF4;
      border: 1.5px solid #22C55E;
      color: #15803D;
      border-radius: 16px;
      padding: 12px 16px;
      font-weight: 800;
      font-size: 13px;
      cursor: pointer;
      display: flex;
      align-items: center;
      justify-content: center;
      gap: 8px;
      box-shadow: none;
      transition: all 0.2s ease;
    }
    .btn-view-receipt:active {
      transform: scale(0.98);
    }

    .btn-order-another {
      background: var(--caramel-accent) !important;
      border: 1px solid var(--caramel-accent) !important;
      color: #110E0C !important;
      border-radius: 16px !important;
      padding: 13px 24px !important;
      font-weight: 800 !important;
      font-size: 13.5px !important;
      cursor: pointer;
      display: inline-flex;
      align-items: center;
      justify-content: center;
      gap: 7px;
      box-shadow: 0 4px 14px rgba(0, 0, 0, 0.3) !important;
      transition: all 0.2s ease;
      letter-spacing: 0.3px;
      text-decoration: none;
    }
    .btn-order-another.secondary {
      background: rgba(255, 255, 255, 0.06) !important;
      border: 1px solid var(--border-subtle) !important;
      color: var(--text-light) !important;
      box-shadow: none !important;
    }
    .btn-order-another:active {
      transform: scale(0.97);
    }

    /* READY ALARM BANNER & NON-NEON ALERT */
    body.alarm-active {
      /* Clean non-strobe state */
    }
    .ready-alarm-box {
      background: rgba(40, 26, 18, 0.78);
      border: 1.5px solid var(--caramel-accent);
      border-radius: var(--radius-lg);
      padding: 20px 16px;
      margin-top: 16px;
      box-shadow: none;
    }
    @keyframes alertPulse {
      0% { transform: scale(0.99); }
      100% { transform: scale(1.0); }
    }
    .ready-alarm-title { font-size: 20px; font-weight: 800; font-family: 'Cinzel', serif; color: var(--caramel-accent); letter-spacing: 1px; }
    @keyframes spin {
      0% { transform: rotate(0deg); }
      100% { transform: rotate(360deg); }
    }
    .btn-spinner {
      width: 14px;
      height: 14px;
      border: 2px solid currentColor;
      border-top-color: transparent;
      border-radius: 50%;
      display: inline-block;
      animation: spin 0.7s linear infinite;
      vertical-align: middle;
      margin-right: 6px;
    }
    .ready-alarm-sub { font-size: 13px; color: var(--text-light); margin-top: 6px; font-weight: 600; }
    .btn-silence {
      background: #288C78;
      color: #FFFFFF;
      border: none;
      border-radius: var(--radius-md);
      padding: 12px 26px;
      font-size: 14px;
      font-weight: 800;
      margin-top: 14px;
      cursor: pointer;
      box-shadow: none;
    }

    .empty-state {
      grid-column: 1 / -1;
      text-align: center;
      padding: 60px 20px;
      color: var(--text-muted);
    }
    .empty-icon { font-size: 40px; margin-bottom: 10px; opacity: 0.6; }

    @media print {
      body * { visibility: hidden; }
      #orderReceiptModal, #orderReceiptModal .modal-content, #orderReceiptModal .modal-content * {
        visibility: visible;
      }
      #orderReceiptModal {
        position: fixed;
        left: 0;
        top: 0;
        width: 100vw;
        height: auto;
        background: #ffffff !important;
        color: #000000 !important;
        display: block !important;
        padding: 0 !important;
        margin: 0 !important;
      }
      #orderReceiptModal .modal-content {
        background: #ffffff !important;
        color: #000000 !important;
        border: none !important;
        box-shadow: none !important;
        padding: 10px !important;
        max-width: 100% !important;
      }
      .no-print { display: none !important; }
    }

    @keyframes eqBounce {
      0%, 100% { height: 6px; }
      50% { height: 24px; }
    }
    @keyframes custVolGlow {
      0% { transform: scale(0.99); }
      100% { transform: scale(1.0); }
    }

    /* Customer Feedback & Rating Modal */
    .cust-star-row {
      display: flex;
      justify-content: center;
      align-items: center;
      gap: 10px;
      margin: 12px 0 6px 0;
    }
    .cust-star-btn {
      background: none;
      border: none;
      padding: 6px;
      cursor: pointer;
      display: flex;
      align-items: center;
      justify-content: center;
      border-radius: 12px;
      transition: transform 0.18s cubic-bezier(0.18, 0.89, 0.32, 1.28);
      touch-action: manipulation;
    }
    .cust-star-btn:hover {
      transform: scale(1.18);
    }
    .cust-star-btn:active {
      transform: scale(0.9);
    }
    .cust-star-svg {
      width: 36px;
      height: 36px;
      transition: transform 0.15s ease;
      filter: none;
    }
    .cust-rating-descriptor {
      font-size: 13px;
      font-weight: 700;
      color: #E2DBD4;
      letter-spacing: 0.3px;
      margin-top: 5px;
      min-height: 20px;
      text-shadow: none;
    }
    .cust-fb-chip {
      background: rgba(255, 255, 255, 0.05);
      border: 1px solid rgba(255, 255, 255, 0.12);
      color: #D6C8BD;
      border-radius: 10px;
      padding: 7px 11px;
      font-size: 11.5px;
      font-weight: 600;
      cursor: pointer;
      display: inline-flex;
      align-items: center;
      gap: 5px;
      transition: all 0.15s ease;
      user-select: none;
      font-family: inherit;
    }
    .cust-fb-chip:hover {
      background: rgba(255, 255, 255, 0.09);
      border-color: rgba(255, 255, 255, 0.22);
    }
    .cust-fb-chip:active {
      transform: scale(0.97);
    }
    .cust-fb-chip.active {
      background: #D4AF37;
      border-color: #D4AF37;
      color: #110E0C;
      font-weight: 700;
      box-shadow: none;
    }
    .cust-fb-textarea {
      width: 100%;
      box-sizing: border-box;
      background: rgba(255, 255, 255, 0.03);
      border: 1px solid rgba(255, 255, 255, 0.12);
      border-radius: 12px;
      padding: 10px 12px;
      color: #FFFFFF;
      font-size: 12.5px;
      font-family: inherit;
      resize: none;
      outline: none;
      transition: border-color 0.15s ease;
    }
    .cust-fb-textarea:focus {
      border-color: #D4AF37;
      background: rgba(255, 255, 255, 0.05);
      box-shadow: none;
    }
    #btnCancelOrder {
      background: #DC2626 !important;
      color: #FFFFFF !important;
      border: 1.5px solid #DC2626 !important;
      box-shadow: 0 4px 14px rgba(220, 38, 38, 0.4) !important;
    }
    #btnCancelOrder:hover {
      background: #B91C1C !important;
      border-color: #B91C1C !important;
      box-shadow: 0 6px 18px rgba(220, 38, 38, 0.55) !important;
    }
    #btnCancelOrder:active {
      transform: translateY(0);
    }
    #btnCancelOrder svg, #btnCancelOrder span {
      color: #FFFFFF !important;
      stroke: #FFFFFF !important;
    }
  </style>
</head>
<body>
  <!-- Header Bar -->
  <header>
    <div class="brand">
      <div class="brand-logo-frame">
        <img src="/logo.png" alt="Logo" onerror="this.parentElement.innerHTML='<span style=\\'font-weight:800;color:#D4AF37;\\'>C</span>'">
      </div>
      <div>
        <div class="brand-title">CELESTIAL CAFE</div>
        <div class="brand-sub">Cozy&Classic</div>
      </div>
    </div>
    <div class="header-right" style="display: flex; align-items: center; gap: 8px;">
      <div class="live-dot-pulse" title="Connected to Cafe Hotspot"></div>
      <button type="button" id="tablePill" class="table-pill" onclick="showDiningOptionModal()" title="Tap to switch between Take Out and Dine-In" style="cursor: pointer; pointer-events: auto;"><svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="color: var(--gold-light); vertical-align: -1px; margin-right: 3px;"><path d="M3 2v7c0 1.1.9 2 2 2h4a2 2 0 0 0 2-2V2"></path><path d="M7 2v20"></path><path d="M21 15V2v0a5 5 0 0 0-5 5v6c0 1.1.9 2 2 2h3Zm0 0v7"></path></svg><span id="tablePillLabel">Table 1</span><svg width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" style="opacity: 0.7; margin-left: 2px;"><polyline points="6 9 12 15 18 9"></polyline></svg></button>
    </div>
  </header>

  <!-- Sticky Controls: Search Bar + Category Pills -->
  <div class="controls-wrapper" id="controlsWrapper">
    <div class="search-box">
      <span class="search-icon-pos">
        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><circle cx="11" cy="11" r="8"></circle><line x1="21" y1="21" x2="16.65" y2="16.65"></line></svg>
      </span>
      <input type="text" id="searchInput" class="search-input" placeholder="Search coffee, tea, pastries, meals..." oninput="handleSearch(this.value)">
      <button id="clearSearchBtn" class="clear-search-btn" onclick="clearSearch()">✕</button>
    </div>

    <div class="cat-bar" id="catBar">
      <button class="cat-tab active" onclick="filterCategory('all', this)">All Items</button>
      <button class="cat-tab" onclick="filterCategory('coffee', this)">Coffee</button>
      <button class="cat-tab" onclick="filterCategory('frappe', this)">Frappe</button>
      <button class="cat-tab" onclick="filterCategory('milktea', this)">Milk Tea</button>
      <button class="cat-tab" onclick="filterCategory('cheesecakeSeries', this)">Cheesecake</button>
      <button class="cat-tab" onclick="filterCategory('streetBites', this)">Bites</button>
      <button class="cat-tab" onclick="filterCategory('pastaDishes', this)">Pasta</button>
      <button class="cat-tab" onclick="filterCategory('sandwich', this)">Sandwich</button>
      <button class="cat-tab" onclick="filterCategory('dinner', this)">Dinner Meals</button>
    </div>
  </div>

  <!-- Normal Menu View -->
  <div id="menuView">
    <!-- Floating Active Order Quick Access Banner (when customer is browsing menu while order is active) -->
    <div id="menuActiveOrderFloatingPill" onclick="showActiveOrderTracker()" style="display: none; margin: 10px 14px 14px 14px; background: linear-gradient(135deg, rgba(20, 16, 13, 0.96) 0%, rgba(27, 21, 17, 0.96) 100%); border: 1.5px solid rgba(212, 175, 55, 0.45); border-radius: 16px; padding: 11px 16px; box-shadow: 0 8px 24px rgba(0,0,0,0.5); cursor: pointer; transition: all 0.2s ease;">
      <div style="display: flex; align-items: center; justify-content: space-between;">
        <div style="display: flex; align-items: center; gap: 10px;">
          <span class="queue-live-dot"></span>
          <div>
            <div style="font-size: 10px; font-weight: 800; color: #A89B91; text-transform: uppercase; letter-spacing: 0.8px;">Active Order in Kitchen</div>
            <div id="floatingOrderPillText" style="font-size: 13.5px; font-weight: 800; color: #FFFFFF; font-family: 'Outfit', sans-serif;">Order #1 • Brewing</div>
          </div>
        </div>
        <div style="display: flex; align-items: center; gap: 5px; background: rgba(212,175,55,0.15); border: 1px solid rgba(212,175,55,0.3); border-radius: 12px; padding: 5px 10px; color: var(--gold-light); font-size: 11.5px; font-weight: 800;">
          <span>View Ticket</span>
          <span>➔</span>
        </div>
      </div>
    </div>

    <!-- Celestial Signature Craft Hero Banner (Tactile Micro-Skeuomorphism) -->
    <div class="hero-spotlight-card" id="heroSpotlight" onclick="openSignatureLatteItem()" style="cursor: pointer;" title="Tap to customize & order Celestial Signature Latte">
      <div class="hero-spotlight-bg" style="background-image: url('/assets/images/hero_coffee_splash.jpg');"></div>
      <div class="hero-spotlight-overlay"></div>
      <div class="hero-spotlight-content">
        <div class="hero-spotlight-badge">
          <svg width="11" height="11" viewBox="0 0 24 24" fill="currentColor">
            <path d="M10 2L12.1 7.9L18 10L12.1 12.1L10 18L7.9 12.1L2 10L7.9 7.9L10 2Z" />
            <path d="M19 16L19.9 18.1L22 19L19.9 19.9L19 22L18.1 19.9L16 19L18.1 18.1L19 16Z" />
          </svg>
          <span>SIGNATURE CRAFT</span>
        </div>
        <div class="hero-spotlight-title">Celestial Signature Latte</div>
        <div class="hero-spotlight-sub">House specialty handcrafted celestial latte blend with silky sweet foam • Tap to order</div>
      </div>
      <div class="hero-spotlight-action">
        <button type="button" class="hero-spotlight-order-btn" onclick="event.stopPropagation(); openSignatureLatteItem();" title="Order Celestial Signature Latte">
          <svg width="13" height="13" viewBox="0 0 24 24" fill="currentColor">
            <path d="M10 2L12.1 7.9L18 10L12.1 12.1L10 18L7.9 12.1L2 10L7.9 7.9L10 2Z" />
            <path d="M19 16L19.9 18.1L22 19L19.9 19.9L19 22L18.1 19.9L16 19L18.1 18.1L19 16Z" />
          </svg>
          <span>Order</span>
        </button>
      </div>
    </div>

    <div class="section-header">
      <div class="section-title" id="sectionTitleLabel">All Menu Items</div>
      <div class="item-counter-badge" id="menuCountBadge">0 items</div>
    </div>
    <div class="menu-container" id="menuGrid"></div>
  </div>

  <!-- Active Order Tracker View (Authentic POS Thermal Receipt Printer Design) -->
  <div id="trackerView" style="display: none;">
    <div class="printer-housing">
      <!-- Metallic Silver Thermal Printer Bezel Slot -->
      <div class="printer-bezel">
        <div class="printer-slot-mouth"></div>
      </div>

      <!-- Emergent Receipt Paper Viewport (Downwards feed animation) -->
      <div class="printer-feed-viewport">
        <div class="tracker-card thermal-receipt-paper printing-feed-anim" id="thermalReceiptPaper">
          <div class="receipt-inner-body">
            <!-- Hidden compatibility stubs for existing JS functions -->
            <div style="display: none !important;">
              <div id="trackerHeaderTag"><span id="trackerHeaderTagText"></span></div>
              <div id="pendingPaymentNotice"></div>
              <div id="confirmedPaymentNotice"></div>
              <div id="brewingNotice"></div>
              <div id="readyNotice"><span id="readyNoticeOrderNum"></span></div>
              <div id="completedNotice"></div>
              <span id="trackedItemsCount">0</span>
              <div id="trackerOrderDetailsList"></div>
              <img id="receiptQrImg" src="" />
              <div id="ticketBarcodeSerial"></div>
              <button id="btnOpenOrderModal"></button>
            </div>
            <div class="receipt-dash-rule">- - - - - - - - - - - - - - - - - - - - - - - -</div>
            <div class="receipt-dash-rule" style="margin-top: -3px;">- - - - - - - - - - - - - - - - - - - - - - - -</div>

            <!-- Wi-Fi Disconnect Alert Banner -->
            <div id="wifiWarningBanner" style="display: none; background: #FEF2F2; border: 1px solid #F87171; border-radius: 12px; padding: 8px 12px; margin: 8px 0; text-align: center; color: #DC2626; font-size: 11.5px; font-weight: 700;">
              Wi-Fi Disconnected! Please reconnect to Cafe Wi-Fi.
            </div>

            <!-- Slow Connection / Loading Banner -->
            <div id="slowConnectionBanner" style="display: none; text-align: center; margin: 8px 0;">
              <span style="width: 14px; height: 14px; border: 2px solid #D97706; border-top-color: transparent; border-radius: 50%; display: inline-block; animation: spin 0.8s linear infinite;"></span>
            </div>

            <!-- Wi-Fi Keep Connected Notice Pill -->
            <div id="wifiStatusPill" class="receipt-wifi-pill">
              <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.3" stroke-linecap="round" stroke-linejoin="round"><path d="M5 12.55a11 11 0 0 1 14.08 0"></path><path d="M1.42 9a16 16 0 0 1 21.16 0"></path><path d="M8.53 16.11a6 6 0 0 1 6.95 0"></path><line x1="12" y1="20" x2="12.01" y2="20"></line></svg>
              <span>Wi-Fi Connected • Live Updates</span>
            </div>

            <!-- Order Number Hero Box in Thermal Receipt Style -->
            <div class="receipt-order-hero">
              <div class="receipt-order-label">ORDER NUMBER</div>
              <div class="receipt-order-num" id="trackOrderNum">#1</div>
              <div id="trackTableInfo" class="receipt-table-pill">Table 1 (Dine-In at Table)</div>
            </div>

            <!-- Instruction Banner Card (Stamped Receipt Seal) -->
            <div class="tracker-instruction-card" id="trackerInstructionCard">
              <div class="tracker-instruction-title" id="trackerInstructionTitle">
                SHOW ORDER NUMBER <span id="promptOrderNum">#1</span> AT CASHIER TO PAY AND CONFIRM
              </div>
              <div class="tracker-instruction-status" id="trackerStatusDisplay">
                Status: Awaiting Cashier
              </div>
            </div>

            <!-- Stepper Milestone Tracker -->
            <div class="status-steps">
              <div class="status-step active" id="step1">
                <div class="step-dot">1</div>
                <div class="step-label">At Cashier</div>
              </div>
              <div class="status-step" id="step2">
                <div class="step-dot">2</div>
                <div class="step-label">Brewing</div>
              </div>
              <div class="status-step" id="step3">
                <div class="step-dot">3</div>
                <div class="step-label">Ready</div>
              </div>
            </div>

            <!-- Estimated Waiting Time -->
            <div class="tracker-wait-time-row">
              <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.3" stroke-linecap="round" stroke-linejoin="round" style="display: inline-block; vertical-align: -2px; margin-right: 4px; color: #8C5B2C;"><circle cx="12" cy="12" r="10"></circle><polyline points="12 6 12 12 16 14"></polyline></svg>
              Estimated Waiting Time: <span id="trackerWaitTime" class="wait-time-highlight">5 Minutes</span>
            </div>

            <div class="receipt-dash-rule" style="margin: 12px 0 8px 0;">- - - - - - - - - - - - - - - - - - - - - - - -</div>

            <!-- Ordered Items Receipt Breakdown (Matching reference image) -->
            <div id="receiptItemsContainer" class="receipt-items-table">
              <div class="receipt-item-line">
                <span class="receipt-item-name">1x Order Initializing...</span>
                <span class="receipt-item-price">₱0.00</span>
              </div>
            </div>

            <div class="receipt-dash-rule" style="margin: 8px 0 10px 0;">- - - - - - - - - - - - - - - - - - - - - - - -</div>

            <!-- Financial Total Section (Matching image TOTAL AMOUNT) -->
            <div class="receipt-total-section">
              <div class="receipt-total-row">
                <span class="receipt-total-name">TOTAL AMOUNT</span>
                <span class="receipt-total-val" id="trackTotal">₱0.00</span>
              </div>
            </div>

            <div class="receipt-dash-rule" style="margin: 12px 0 10px 0;">- - - - - - - - - - - - - - - - - - - - - - - -</div>

            <!-- Centered THANK YOU matching reference image -->
            <div class="receipt-thank-you">THANK YOU</div>

            <div class="receipt-dash-rule" style="margin: 12px 0 8px 0;">- - - - - - - - - - - - - - - - - - - - - - - -</div>

            <!-- Receipt Ticket Action Controls (Inside the Ticket) -->
            <div class="receipt-ticket-actions" style="margin-top: 6px; display: flex; flex-direction: column; gap: 8px;">
              <!-- Live Kitchen Activity Pop-up Modal Button -->
              <button onclick="openKitchenQueueModal()" id="btnOpenKitchenQueueModal" class="btn-kitchen-queue">
                <div style="display: flex; align-items: center; gap: 8px;">
                  <span class="queue-live-dot"></span>
                  <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" style="color: var(--amber-brewing);"><path d="M18 8h1a4 4 0 0 1 0 8h-1"></path><path d="M2 8h16v9a4 4 0 0 1-4 4H6a4 4 0 0 1-4-4V8z"></path><line x1="6" y1="1" x2="6" y2="4"></line><line x1="10" y1="1" x2="10" y2="4"></line><line x1="14" y1="1" x2="14" y2="4"></line></svg>
                  <span>Live Kitchen Activity</span>
                </div>
                <span id="trackerQueueSummaryBadge" class="queue-badge-pill">0 brewing • 0 in queue</span>
              </button>

              <!-- Pending Order Actions: Cancel Order -->
              <div id="pendingActionButtons">
                <button onclick="cancelCustomerOrder()" id="btnCancelOrder" style="width: 100%; background: #DC2626; border: 1.5px solid #DC2626; color: #FFFFFF; border-radius: 14px; padding: 11px 16px; font-weight: 700; font-size: 13px; cursor: pointer; display: flex; align-items: center; justify-content: center; gap: 8px; transition: all 0.15s; box-shadow: 0 4px 14px rgba(220, 38, 38, 0.4);">
                  <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="#FFFFFF" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"></circle><line x1="15" y1="9" x2="9" y2="15"></line><line x1="9" y1="9" x2="15" y2="15"></line></svg>
                  <span style="color: #FFFFFF; font-weight: 700;">Cancel Order</span>
                </button>
              </div>

              <!-- Order More / New Order Button -->
              <button onclick="newOrder(true)" id="btnOrderAnotherItem" class="btn-order-another" style="display: none; width: 100%; justify-content: center;">
                <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M3 12a9 9 0 0 1 9-9 9.75 9.75 0 0 1 6.74 2.74L21 8"></path><polyline points="21 3 21 8 16 8"></polyline><path d="M21 12a9 9 0 0 1-9 9 9.75 9.75 0 0 1-6.74-2.74L3 16"></path><polyline points="8 16 3 16 3 21"></polyline></svg>
                <span>Order Again</span>
              </button>
            </div>
          </div>

          <!-- Serrated Sawtooth Paper Tear Bottom Edge -->
          <div class="ticket-sawtooth-bottom" aria-hidden="true">
            <svg viewBox="0 0 320 12" preserveAspectRatio="none" style="width: 100%; height: 12px; display: block;">
              <defs>
                <pattern id="ticketSawTeeth" width="16" height="12" patternUnits="userSpaceOnUse">
                  <polygon points="0,0 8,12 16,0" fill="#000000" />
                </pattern>
              </defs>
              <rect width="100%" height="12" fill="url(#ticketSawTeeth)" />
            </svg>
          </div>
        </div>
      </div>
    </div>
  </div>

  <!-- Bottom Floating Tray -->
  <div class="cart-bar" id="cartBar" style="display: none;">
    <div class="cart-summary">
      <span class="cart-count" id="cartCountText">0 items</span>
      <span class="cart-total" id="cartTotalText">₱0</span>
    </div>
    <button class="btn-view-tray" onclick="openTrayModal()">
      <span>View Tray</span>
      <span>➔</span>
    </button>
  </div>

  <!-- Customization Modal (Showcase Card & Segmented Controls) -->
  <div class="modal-overlay" id="customModal" onclick="if(event.target===this) closeModal('customModal')">
    <div class="custom-dialog-card">
      <!-- Scrollable Body with Top Product Showcase & Customization Groups -->
      <div class="cust-dlg-body">
        <!-- Top Product Showcase Card (Reference Design) -->
        <div class="cust-showcase-card">
          <div class="cust-showcase-img-box" id="modalThumbBox">
            <button class="cust-img-close-btn" onclick="closeModal('customModal')" aria-label="Close dialog">✕</button>
            <img src="" id="modalThumbImg" alt="Item" onerror="this.style.display='none'; document.getElementById('modalThumbIcon').style.display='flex';">
            <div id="modalThumbIcon" style="display: none; align-items: center; justify-content: center; width: 100%; height: 100%;"><span style="font-size: 54px;">☕</span></div>
          </div>
          <div class="cust-showcase-info">
            <div class="cust-showcase-name" id="modalItemName">Americano</div>
            <div class="cust-showcase-price" id="modalBasePriceBadge">₱90</div>
            <div class="cust-showcase-desc" id="modalItemDesc" style="display: none;"></div>
          </div>
        </div>

        <!-- Customization Groups Container -->
        <div id="customGroupContainer"></div>
      </div>

      <!-- Footer Bar with Stepper & Add to Order Button -->
      <div class="cust-dlg-footer">
        <div class="cust-stepper">
          <button class="cust-stepper-btn" onclick="changeModalQty(-1)" aria-label="Decrease quantity">−</button>
          <span class="cust-stepper-val" id="modalQtyDisplay">1</span>
          <button class="cust-stepper-btn" onclick="changeModalQty(1)" aria-label="Increase quantity">+</button>
        </div>
        <button class="cust-add-btn" id="btnAddItemToCart" onclick="confirmAddToCart()">
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"><circle cx="9" cy="21" r="1"></circle><circle cx="20" cy="21" r="1"></circle><path d="M1 1h4l2.68 13.39a2 2 0 0 0 2 1.61h9.72a2 2 0 0 0 2-1.61L23 6H6"></path></svg>
          <span id="modalAddBtnText">Add to Order • ₱90</span>
        </button>
      </div>
    </div>
  </div>

  <!-- Tray & Checkout Modal -->
  <div class="modal-overlay" id="trayModal">
    <div class="modal-content">
      <div class="modal-drag-pill"></div>
      <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px;">
        <div class="modal-title">Your Order Tray</div>
        <button onclick="closeModal('trayModal')" style="background: rgba(255,255,255,0.08); border: none; border-radius: 50%; width: 32px; height: 32px; font-size: 14px; color: var(--text-muted); cursor: pointer; display: flex; align-items: center; justify-content: center;">✕</button>
      </div>

      <div id="trayItemsList" style="max-height: 38vh; overflow-y: auto; margin-bottom: 16px;"></div>

      <!-- Single Confirmed Dining Option Banner (Dine-In OR Takeout) -->
      <div id="trayDineInBanner" style="margin-bottom: 14px; background: rgba(212,175,55,0.12); border: 1.2px solid var(--gold-primary); border-radius: var(--radius-md); padding: 10px 14px; display: flex; align-items: center; justify-content: space-between;">
        <div style="display: flex; align-items: center; gap: 8px;">
          <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="var(--gold-light)" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M3 2v7c0 1.1.9 2 2 2h4a2 2 0 0 0 2-2V2"></path><path d="M7 2v20"></path><path d="M21 15V2v0a5 5 0 0 0-5 5v6c0 1.1.9 2 2 2h3Zm0 0v7"></path></svg>
          <div>
            <div style="font-size: 13px; font-weight: 800; color: var(--gold-light); font-family: 'Cinzel', serif;">Dine-In Order</div>
            <div style="font-size: 11.5px; color: var(--text-muted);" id="trayDineInTableText">Table 1 (Dine-In at Table)</div>
          </div>
        </div>
        <button type="button" onclick="showDiningOptionModal()" style="font-size: 11px; font-weight: 800; background: rgba(212,175,55,0.22); color: var(--gold-light); border: 1px solid rgba(212,175,55,0.45); padding: 5px 11px; border-radius: 8px; cursor: pointer; display: flex; align-items: center; gap: 4px; transition: all 0.15s ease;">
          <span>Change</span>
          <svg width="11" height="11" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polyline points="6 9 12 15 18 9"></polyline></svg>
        </button>
      </div>

      <div id="trayTakeoutBanner" style="display: none; margin-bottom: 14px; background: rgba(255,159,28,0.14); border: 1.2px solid #FF9F1C; border-radius: var(--radius-md); padding: 10px 14px; display: flex; align-items: center; justify-content: space-between;">
        <div style="display: flex; align-items: center; gap: 8px;">
          <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="#FFB74D" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M6 2L3 6v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2V6l-3-4z"></path><line x1="3" y1="6" x2="21" y2="6"></line><path d="M16 10a4 4 0 0 1-8 0"></path></svg>
          <div>
            <div style="font-size: 13px; font-weight: 800; color: #FFB74D; font-family: 'Cinzel', serif;">Take Out Order</div>
            <div style="font-size: 11px; color: var(--text-light);">Packed in paper cups & bags for counter pickup</div>
          </div>
        </div>
        <button type="button" onclick="showDiningOptionModal()" style="font-size: 11px; font-weight: 800; background: rgba(255,159,28,0.25); color: #FFB74D; border: 1px solid rgba(255,159,28,0.45); padding: 5px 11px; border-radius: 8px; cursor: pointer; display: flex; align-items: center; gap: 4px; transition: all 0.15s ease;">
          <span>Change</span>
          <svg width="11" height="11" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polyline points="6 9 12 15 18 9"></polyline></svg>
        </button>
      </div>

      <div class="opt-group-title" id="custNameLabel">Guest Name</div>
      <input type="text" id="custNameInput" placeholder="Enter your name (e.g. Maria, John)" style="width: 100%; background: var(--bg-card); border: 1px solid var(--border-subtle); border-radius: var(--radius-md); padding: 12px 14px; color: var(--text-light); font-size: 13.5px; margin-bottom: 14px; outline: none;">

      <div class="opt-group-title">Payment Method</div>
      <div class="opt-grid">
        <div class="opt-chip selected" onclick="selectPayment('cash', this)">Pay Cash at Counter</div>
        <div class="opt-chip" onclick="selectPayment('gcash', this)">Pay GCash at Counter</div>
      </div>

      <div style="border-top: 1px dashed rgba(255,255,255,0.12); padding-top: 14px; margin-top: 16px; display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px;">
        <span style="font-weight: 700; font-size: 14px; color: var(--text-muted);">Total Amount</span>
        <span style="font-weight: 800; font-size: 24px; color: #FFFFFF;" id="trayTotalAmount">₱0</span>
      </div>

      <button onclick="submitOrderToKitchen()" id="btnSendOrder" style="width: 100%; background: var(--caramel-accent); color: #110E0C; border: none; border-radius: var(--radius-md); padding: 16px; font-weight: 800; font-size: 15.5px; cursor: pointer; box-shadow: 0 4px 14px rgba(0, 0, 0, 0.35); transition: all 0.15s ease;">
        Submit Order to Cashier
      </button>
    </div>
  </div>

  <!-- Unverified Table QR Modal (Blocks direct URL editing to arbitrary tables) -->
  <div class="modal-overlay" id="unverifiedTableModal" style="display: none; z-index: 999999; background: rgba(0, 0, 0, 0.94); backdrop-filter: blur(8px);">
    <div class="modal-content" style="max-width: 430px; margin: 0 auto; background: #161219; border: 2px solid rgba(229, 57, 53, 0.7); border-radius: 24px; padding: 28px 22px; box-shadow: 0 16px 60px rgba(0,0,0,0.98); text-align: center; animation: popIn 0.22s cubic-bezier(0.18, 0.89, 0.32, 1.28);">
      
      <div style="width: 72px; height: 72px; border-radius: 50%; background: rgba(229, 57, 53, 0.16); border: 2.2px solid rgba(229, 57, 53, 0.6); display: flex; align-items: center; justify-content: center; margin: 0 auto 16px auto; box-shadow: none;">
        <svg width="36" height="36" viewBox="0 0 24 24" fill="none" stroke="#E53935" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round">
          <rect x="3" y="11" width="18" height="11" rx="2" ry="2"></rect>
          <path d="M7 11V7a5 5 0 0 1 10 0v4"></path>
        </svg>
      </div>

      <div style="font-family: 'Cinzel', serif; font-size: 18px; font-weight: 800; color: #FF6B6B; letter-spacing: 1px;">MENU ACCESS BLOCKED</div>
      <div style="font-size: 14.5px; font-weight: 700; color: #FFFFFF; margin-top: 6px;" id="unverifiedTableTitle">Direct Table Link Not Allowed</div>
      <div style="font-size: 13px; color: var(--text-muted); margin-top: 10px; line-height: 1.55;" id="unverifiedTableBody">
        You cannot access the menu by editing or typing the table link in your browser. Each table has its own unique physical QR code.
      </div>

      <div style="background: rgba(229, 57, 53, 0.12); border: 1.5px dashed rgba(229, 57, 53, 0.45); border-radius: 16px; padding: 16px 14px; color: #FF8A80; font-size: 12.8px; line-height: 1.5; margin-top: 20px; text-align: center;">
        <div style="font-weight: 800; font-size: 14px; margin-bottom: 5px; color: #FF5252;">📷 Physical QR Scan Required</div>
        Please point your mobile camera at the actual QR code on your table's acrylic stand to unlock and view the menu.
      </div>
    </div>
  </div>

  <!-- Dining Option Modal (Dine-In or Takeout) - First Appearance Prompt -->
  <div class="modal-overlay" id="diningOptionModal" style="display: none;" onclick="if(event.target===this) closeModal('diningOptionModal')">
    <div class="modal-content" style="max-width: 440px; margin: 0 auto; background: #14100D; border: 1px solid rgba(255, 255, 255, 0.12); border-radius: 24px; padding: 22px; box-shadow: 0 16px 40px rgba(0,0,0,0.7); animation: popIn 0.22s cubic-bezier(0.18, 0.89, 0.32, 1.28);">
      <div class="modal-drag-pill"></div>

      <div style="text-align: center; margin-bottom: 18px;">
        <div class="brand-logo-frame" style="margin: 0 auto 10px auto; width: 48px; height: 48px; border-radius: 50%; border: 1.5px solid rgba(212, 175, 55, 0.45);">
          <img src="/logo.png" alt="Logo" onerror="this.parentElement.innerHTML='<span style=\\'font-weight:800;color:#FFFFFF;font-size:22px;\\'>C</span>'">
        </div>
        <div style="font-family: 'Cinzel', serif; font-size: 18.5px; font-weight: 800; color: #FFFFFF; letter-spacing: 1px;">WELCOME TO CELESTIAL CAFE</div>
        <div style="font-size: 12.5px; color: #A89B91; margin-top: 4px;">How will you enjoy your order today?</div>
      </div>

      <div style="display: flex; flex-direction: column; gap: 12px; margin-bottom: 18px;">
        <!-- Option 1: Dine-In -->
        <div class="dining-card selected" id="cardDineIn" onclick="selectDiningOption('dineIn')">
          <div class="dining-icon-box">
            <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="var(--caramel-accent)" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M3 2v7c0 1.1.9 2 2 2h4a2 2 0 0 0 2-2V2"></path><path d="M7 2v20"></path><path d="M21 15V2v0a5 5 0 0 0-5 5v6c0 1.1.9 2 2 2h3Zm0 0v7"></path></svg>
          </div>
          <div style="flex: 1; min-width: 0;">
            <div style="display: flex; align-items: center; justify-content: space-between;">
              <span style="font-weight: 800; font-size: 15px; color: #FFFFFF; font-family: 'Cinzel', serif;">Dine-In</span>
              <span id="dineInCheck" style="font-size: 16px; color: var(--caramel-accent); font-weight: 900;">✓</span>
            </div>
            <div style="font-size: 12px; color: var(--text-light); margin-top: 3px; line-height: 1.35;">Enjoy inside our cafe at your table. Served in glassware and plates.</div>
            <div style="margin-top: 8px; display: flex; align-items: center; justify-content: space-between; gap: 6px; background: rgba(255, 255, 255, 0.05); border: 1px solid rgba(255, 255, 255, 0.1); border-radius: 8px; padding: 5px 9px;">
              <div style="display: flex; align-items: center; gap: 4px; min-width: 0;">
                <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="var(--caramel-accent)" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" style="flex-shrink: 0;"><path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z"></path><circle cx="12" cy="10" r="3"></circle></svg>
                <span id="welcomeScannedTable" style="font-size: 11.5px; font-weight: 800; color: #FFFFFF; white-space: nowrap; overflow: hidden; text-overflow: ellipsis;">Table 1</span>
              </div>
              <div id="welcomeTableBadge" style="flex-shrink: 0; white-space: nowrap;"></div>
            </div>
          </div>
        </div>

        <!-- Option 2: Takeout -->
        <div class="dining-card takeout-card" id="cardTakeout" onclick="selectDiningOption('takeaway')">
          <div class="dining-icon-box">
            <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="var(--caramel-accent)" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M6 2L3 6v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2V6l-3-4z"></path><line x1="3" y1="6" x2="21" y2="6"></line><path d="M16 10a4 4 0 0 1-8 0"></path></svg>
          </div>
          <div style="flex: 1; min-width: 0;">
            <div style="display: flex; align-items: center; justify-content: space-between;">
              <span style="font-weight: 800; font-size: 15px; color: #FFFFFF; font-family: 'Cinzel', serif;">Take Out</span>
              <span id="takeoutCheck" style="font-size: 16px; color: var(--caramel-accent); font-weight: 900; display: none;">✓</span>
            </div>
            <div style="font-size: 12px; color: var(--text-light); margin-top: 3px; line-height: 1.35;">Packed in take out paper cups, lids, and bags. Pick up freshly at the counter.</div>
            <div style="margin-top: 8px;">
              <span style="background: rgba(255, 255, 255, 0.06); border: 1px solid rgba(255, 255, 255, 0.12); color: #D6C8BD; font-size: 10px; font-weight: 800; padding: 3px 8px; border-radius: 5px; display: inline-flex; align-items: center; gap: 4px; white-space: nowrap;">
                <svg width="11" height="11" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M6 2L3 6v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2V6l-3-4z"></path><line x1="3" y1="6" x2="21" y2="6"></line><path d="M16 10a4 4 0 0 1-8 0"></path></svg>
                <span>TAKE OUT PACKAGING</span>
              </span>
            </div>
          </div>
        </div>
      </div>

      <button type="button" onclick="confirmDiningOptionAndClose()" style="width: 100%; background: var(--caramel-accent); color: #110E0C; border: none; border-radius: var(--radius-md); padding: 14px; font-weight: 800; font-size: 14.5px; cursor: pointer; box-shadow: 0 4px 14px rgba(0, 0, 0, 0.3);">
        Continue to Menu
      </button>
    </div>
  </div>

  <!-- View Order Details Pop-up Modal -->
  <div class="modal-overlay" id="orderDetailsModal" onclick="if(event.target===this) closeModal('orderDetailsModal')">
    <div class="modal-content" style="max-width: 480px; margin: 0 auto; background: #14100D; border: 1.5px solid rgba(212, 163, 89, 0.35); border-radius: 22px; padding: 22px; box-shadow: 0 16px 48px rgba(0,0,0,0.85);">
      <div class="modal-drag-pill"></div>

      <!-- Modal Header -->
      <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 14px;">
        <div>
          <div style="font-family: 'Cinzel', serif; font-size: 19px; font-weight: 900; color: #FFFFFF; letter-spacing: 1.5px;">ORDER DETAILS</div>
          <div style="font-size: 11.5px; color: var(--text-muted); margin-top: 2px;">
            Order <span id="detailsModalOrderNum" style="color: var(--gold-light); font-weight: 800;">#1</span> • <span id="detailsModalTableType">Table 1 • Dine-In</span>
          </div>
        </div>
        <button type="button" onclick="closeModal('orderDetailsModal')" style="background: rgba(255,255,255,0.08); border: 1px solid rgba(255,255,255,0.12); color: var(--text-light); width: 34px; height: 34px; border-radius: 50%; font-size: 16px; cursor: pointer; display: flex; align-items: center; justify-content: center; transition: all 0.15s ease;">✕</button>
      </div>

      <!-- Live Status Banner -->
      <div id="detailsModalStatusBanner" style="display: flex; align-items: center; justify-content: space-between; padding: 10px 14px; border-radius: 12px; margin-bottom: 12px; background: rgba(212,163,89,0.12); border: 1px solid rgba(212,163,89,0.3);">
        <span style="font-size: 10.5px; font-weight: 800; text-transform: uppercase; letter-spacing: 0.8px; color: var(--gold-light);">Status:</span>
        <span id="detailsModalStatusBadge" style="font-weight: 800; font-size: 12px; color: var(--gold-light);">Awaiting Cashier</span>
      </div>

      <!-- Meta Info Box -->
      <div style="background: rgba(255,255,255,0.03); border: 1px solid rgba(255,255,255,0.08); border-radius: 12px; padding: 10px 14px; margin-bottom: 14px; font-size: 11.5px; line-height: 1.65;">
        <div style="display: flex; justify-content: space-between;"><span style="color: var(--text-muted);">Placed Date & Time:</span><span id="detailsModalDateTime" style="font-weight: 600; color: var(--text-light);">--</span></div>
        <div style="display: flex; justify-content: space-between;"><span style="color: var(--text-muted);">Guest / Customer:</span><span id="detailsModalCustomer" style="font-weight: 600; color: var(--text-light);">Guest Patron</span></div>
        <div style="display: flex; justify-content: space-between;"><span style="color: var(--text-muted);">Payment Method:</span><span id="detailsModalPayment" style="font-weight: 700; color: var(--gold-light); text-transform: uppercase;">CASH</span></div>
      </div>

      <!-- Order Items List -->
      <div style="font-size: 11px; font-weight: 800; color: var(--text-muted); text-transform: uppercase; letter-spacing: 0.8px; margin-bottom: 6px;">
        Order Items (<span id="detailsModalItemCount">0</span>)
      </div>
      <div id="detailsModalItemsList" style="max-height: 34vh; overflow-y: auto; background: rgba(0,0,0,0.35); border-radius: 12px; border: 1px solid rgba(255,255,255,0.08); padding: 10px 14px; margin-bottom: 14px;">
        <!-- Items dynamically inserted here -->
      </div>

      <!-- Financial Breakdown -->
      <div style="background: rgba(255,255,255,0.03); border-radius: 12px; border: 1px solid rgba(255,255,255,0.08); padding: 12px 14px; margin-bottom: 16px; font-size: 12px;">
        <div style="display: flex; justify-content: space-between; margin-bottom: 4px; color: var(--text-muted);">
          <span>Subtotal:</span>
          <span id="detailsModalSubtotal" style="font-weight: 700; color: var(--text-light);">₱0</span>
        </div>
        <div id="detailsModalDiscountRow" style="display: none; justify-content: space-between; margin-bottom: 4px; color: var(--rose);">
          <span id="detailsModalDiscountLabel">Discount:</span>
          <span id="detailsModalDiscountAmount" style="font-weight: 700;">-₱0</span>
        </div>
        <div style="display: flex; justify-content: space-between; align-items: baseline; border-top: 1px solid rgba(255,255,255,0.1); padding-top: 8px; margin-top: 6px;">
          <span style="font-size: 13.5px; font-weight: 800; color: var(--gold-light);">TOTAL AMOUNT:</span>
          <span id="detailsModalGrandTotal" style="font-size: 20px; font-weight: 900; color: var(--gold-light);">₱0</span>
        </div>
      </div>

      <!-- Action Button -->
      <button type="button" onclick="closeModal('orderDetailsModal')" style="width: 100%; background: linear-gradient(135deg, var(--caramel-accent) 0%, #A6642E 100%); border: none; color: #110E0C; border-radius: var(--radius-md); padding: 13px; font-weight: 800; font-size: 14px; cursor: pointer; box-shadow: 0 4px 14px rgba(0,0,0,0.4); transition: transform 0.15s ease;">
        Close Details
      </button>
    </div>
  </div>

  <!-- Official Order Receipt Pop-up Modal -->
  <div class="modal-overlay" id="orderReceiptModal" onclick="if(event.target===this) closeModal('orderReceiptModal')">
    <div class="modal-content" style="max-width: 480px; margin: 0 auto; background: #14100D; border: 1px solid rgba(255, 255, 255, 0.12); border-radius: 20px; padding: 20px; box-shadow: 0 16px 40px rgba(0,0,0,0.7);">
      <div class="modal-drag-pill"></div>

      <!-- Receipt Header -->
      <div style="text-align: center; margin-bottom: 12px;">
        <div style="font-family: 'Cinzel', serif; font-size: 20px; font-weight: 900; color: #FFFFFF; letter-spacing: 2px;">CELESTIAL</div>
        <div style="font-size: 10px; font-weight: 700; color: #C48248; letter-spacing: 1.5px; text-transform: uppercase; margin-top: 1px;">Cozy & Classic Artisanal Cafe</div>
        <div style="font-size: 9.5px; color: #A89B91; margin-top: 2px;">Coffee • Milk Tea • Cheesecake • Street Bites</div>
      </div>

      <!-- Paid Stamp / Status Badge -->
      <div id="receiptStampContainer" style="margin-bottom: 12px; text-align: center;">
        <div id="receiptStampBadge" style="display: inline-flex; align-items: center; gap: 6px; padding: 4px 14px; border-radius: 6px; font-weight: 900; font-size: 11.5px; letter-spacing: 1px; text-transform: uppercase; border: 1px solid #288C78; color: #6FE0AC; background: rgba(40,140,120,0.15);">
          ✓ OFFICIAL RECEIPT • PAID
        </div>
      </div>

      <!-- Metadata Box -->
      <div style="background: rgba(255,255,255,0.03); border-top: 1px dashed rgba(255,255,255,0.15); border-bottom: 1px dashed rgba(255,255,255,0.15); padding: 10px 0; margin-bottom: 12px; font-size: 11.5px; color: var(--text-light); line-height: 1.65;">
        <div style="display: flex; justify-content: space-between;">
          <span style="color: var(--text-muted);">Receipt / Order No:</span>
          <span id="receiptOrderNum" style="font-weight: 800; color: #FFFFFF;">#1</span>
        </div>
        <div style="display: flex; justify-content: space-between;">
          <span style="color: var(--text-muted);">Date & Time:</span>
          <span id="receiptDateTime" style="font-weight: 600;">--</span>
        </div>
        <div style="display: flex; justify-content: space-between;">
          <span style="color: var(--text-muted);">Table / Type:</span>
          <span id="receiptTableType" style="font-weight: 700; color: #FFFFFF;">Table 1 • Dine-In</span>
        </div>
        <div style="display: flex; justify-content: space-between;">
          <span style="color: var(--text-muted);">Cashier / Staff:</span>
          <span id="receiptCashierName" style="font-weight: 600;">Cashier Staff</span>
        </div>
        <div style="display: flex; justify-content: space-between;">
          <span style="color: var(--text-muted);">Guest / Customer:</span>
          <span id="receiptCustName" style="font-weight: 600;">Guest Patron</span>
        </div>
      </div>

      <!-- Items List -->
      <div style="font-size: 11px; font-weight: 800; color: var(--text-muted); text-transform: uppercase; letter-spacing: 0.8px; margin-bottom: 6px;">Order Items</div>
      <div id="modalOrderItemsList" style="max-height: 32vh; overflow-y: auto; margin-bottom: 12px; background: rgba(0,0,0,0.3); border-radius: 8px; padding: 10px 12px;">
        <!-- Dynamically rendered items -->
      </div>

      <!-- Financial Breakdown -->
      <div style="border-top: 1px dashed rgba(255,255,255,0.15); padding-top: 10px; margin-bottom: 12px; font-size: 12px; line-height: 1.7;">
        <div style="display: flex; justify-content: space-between; color: var(--text-muted);">
          <span>Subtotal:</span>
          <span id="receiptSubtotal" style="font-weight: 700; color: var(--text-light);">₱0</span>
        </div>
        <div id="receiptDiscountRow" style="display: none; justify-content: space-between; color: var(--rose);">
          <span id="receiptDiscountLabel">Discount:</span>
          <span id="receiptDiscountAmount" style="font-weight: 700;">-₱0</span>
        </div>
        <div style="display: flex; justify-content: space-between; align-items: baseline; border-top: 1px solid rgba(255,255,255,0.1); padding-top: 6px; margin-top: 4px;">
          <span style="font-size: 13.5px; font-weight: 800; color: var(--gold-light);">TOTAL AMOUNT:</span>
          <span id="receiptGrandTotal" style="font-size: 20px; font-weight: 900; color: var(--gold-light);">₱0</span>
        </div>

        <!-- Payment Settlement Info (Visible when confirmed/paid) -->
        <div id="receiptPaymentDetails" style="margin-top: 8px; padding-top: 8px; border-top: 1px dotted rgba(255,255,255,0.12); font-size: 11.5px; color: var(--text-muted);">
          <div style="display: flex; justify-content: space-between;">
            <span>Payment Method:</span>
            <span id="receiptPayMethod" style="font-weight: 700; color: var(--text-light); text-transform: uppercase;">CASH</span>
          </div>
          <div style="display: flex; justify-content: space-between;">
            <span>Amount Tendered:</span>
            <span id="receiptTendered" style="font-weight: 700; color: var(--text-light);">₱0</span>
          </div>
          <div style="display: flex; justify-content: space-between;">
            <span>Change Due:</span>
            <span id="receiptChangeDue" style="font-weight: 800; color: var(--emerald);">₱0</span>
          </div>
        </div>
      </div>

      <!-- Footer Message -->
      <div style="text-align: center; margin-bottom: 14px; font-size: 10.5px; color: var(--text-muted); line-height: 1.4;">
        <div>Thank you for dining at Celestial Cafe!</div>
        <div style="color: var(--gold-light); font-weight: 600; margin-top: 2px;">Please present this official receipt upon order claim.</div>
      </div>

      <!-- Action Buttons -->
      <div>
        <button onclick="closeModal('orderReceiptModal')" class="no-print" style="width: 100%; background: rgba(255,255,255,0.08); border: 1.2px solid rgba(255,255,255,0.18); color: var(--text-light); border-radius: var(--radius-md); padding: 12px; font-weight: 700; font-size: 13px; cursor: pointer; transition: all 0.15s ease;">
          Close
        </button>
      </div>
    </div>
  </div>

  <!-- Dynamic Pop-Up Confirmation Modal -->
  <div class="modal-overlay" id="confirmModal" style="align-items: center; justify-content: center; padding: 20px;" onclick="if(event.target===this) closeModal('confirmModal')">
    <div class="modal-content" style="max-width: 400px; border-radius: var(--radius-xl); border: 1.5px solid var(--border-gold); padding: 26px 20px; text-align: center; margin: auto;">
      <div id="confirmModalIconContainer" style="width: 58px; height: 58px; border-radius: 50%; background: rgba(230,57,70,0.14); border: 1.5px solid var(--rose); display: flex; align-items: center; justify-content: center; margin: 0 auto 16px auto; color: var(--rose);">
        <svg id="confirmModalIcon" width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"></circle><line x1="12" y1="8" x2="12" y2="12"></line><line x1="12" y1="16" x2="12.01" y2="16"></line></svg>
      </div>
      <div class="modal-title" id="confirmModalTitle" style="font-size: 18px; color: var(--text-light); margin-bottom: 8px;">Please Confirm</div>
      <div class="modal-desc" id="confirmModalMsg" style="font-size: 13px; color: var(--text-muted); line-height: 1.5; margin-bottom: 22px;">Are you sure you want to proceed?</div>
      <div style="display: flex; gap: 10px;">
        <button id="btnConfirmCancel" onclick="closeModal('confirmModal')" style="flex: 1; background: rgba(255,255,255,0.08); border: 1px solid rgba(255,255,255,0.18); color: var(--text-light); border-radius: var(--radius-md); padding: 12px; font-weight: 700; font-size: 13px; cursor: pointer;">
          Cancel
        </button>
        <button id="btnConfirmAction" style="flex: 1; background: linear-gradient(135deg, var(--rose) 0%, #B82535 100%); border: none; color: #FFFFFF; border-radius: var(--radius-md); padding: 12px; font-weight: 800; font-size: 13px; cursor: pointer; box-shadow: 0 4px 14px rgba(230,57,70,0.35);">
          Confirm
        </button>
      </div>
    </div>
  </div>

  <!-- Dynamic Pop-Up Success / Notice Modal -->
  <div class="modal-overlay" id="successModal" style="align-items: center; justify-content: center; padding: 20px; z-index: 99999;" onclick="if(event.target===this) closeSuccessModal()">
    <div class="modal-content" style="max-width: 400px; border-radius: var(--radius-xl); border: 1.5px solid var(--emerald); padding: 26px 20px; text-align: center; margin: auto;">
      <div id="successModalIconContainer" style="width: 58px; height: 58px; border-radius: 50%; background: rgba(46,196,182,0.15); border: 1.5px solid var(--emerald); display: flex; align-items: center; justify-content: center; margin: 0 auto 16px auto; color: var(--emerald);">
        <svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"></polyline></svg>
      </div>
      <div class="modal-title" id="successModalTitle" style="font-size: 18.5px; color: var(--text-light); margin-bottom: 8px;">Success!</div>
      <div class="modal-desc" id="successModalMsg" style="font-size: 13px; color: var(--text-muted); line-height: 1.5; margin-bottom: 22px;">Your request was completed successfully.</div>
      <button id="btnSuccessDismiss" onclick="closeSuccessModal()" style="width: 100%; background: linear-gradient(135deg, var(--gold-primary) 0%, #B89025 100%); border: none; color: #0D0A0F; border-radius: var(--radius-md); padding: 13px; font-weight: 800; font-size: 14px; cursor: pointer; box-shadow: none;">
        Continue
      </button>
    </div>
  </div>

  <!-- Ready For Pickup Pop-Up Alarm Modal (Clean Non-Neon Dark Brown) -->
  <div class="modal-overlay" id="readyAlarmModal" style="align-items: center; justify-content: center; padding: 20px; z-index: 300;">
    <div class="modal-content" style="max-width: 420px; width: 100%; border-radius: 24px; border: 1px solid rgba(255, 255, 255, 0.12); padding: 28px 22px; text-align: center; margin: auto; box-shadow: 0 16px 48px rgba(0,0,0,0.85); background: #1C120C;">
      <div style="width: 68px; height: 68px; border-radius: 50%; background: rgba(255, 255, 255, 0.06); border: 1.5px solid var(--caramel-accent); display: flex; align-items: center; justify-content: center; margin: 0 auto 16px auto; color: var(--caramel-accent); box-shadow: none;">
        <svg width="34" height="34" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round">
          <path d="M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9"></path>
          <path d="M13.73 21a2 2 0 0 1-3.46 0"></path>
        </svg>
      </div>

      <div style="font-size: 11px; font-weight: 800; letter-spacing: 2px; text-transform: uppercase; color: var(--caramel-accent); margin-bottom: 6px;">Order Is Ready For Pickup</div>
      
      <div class="modal-title" id="alarmModalOrderNum" style="font-size: 42px; font-family: 'Cinzel', serif; font-weight: 800; color: #FFFFFF; letter-spacing: 2px; text-shadow: none; line-height: 1.15;">#1</div>
      <div id="alarmModalTableInfo" style="font-size: 13px; font-weight: 700; color: var(--warm-beige); margin-top: 5px;">Table 1 • Dine-In</div>

      <div style="font-size: 13.5px; color: #F6EFE9; line-height: 1.5; margin-top: 16px; padding: 14px 16px; background: rgba(255, 255, 255, 0.05); border-radius: var(--radius-md); border: 1px dashed rgba(255, 255, 255, 0.15);">
        Your handcrafted drinks & food are freshly prepared. Please proceed to the <b>Pickup Counter</b> to claim your order.
      </div>

      <button id="btnDismissReadyAlarmModal" onclick="stopAlarm(event)" style="width: 100%; background: var(--caramel-accent); border: none; color: #110E0C; border-radius: var(--radius-md); padding: 15px; font-weight: 900; font-size: 15px; cursor: pointer; box-shadow: none; margin-top: 20px; display: flex; align-items: center; justify-content: center; gap: 8px;">
        <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"></polyline></svg>
        <span>Okay, Claim Order</span>
      </button>
    </div>
  </div>

  <!-- Order Completed & Customer Rating / Feedback Modal -->
  <div class="modal-overlay" id="orderCompletedModal" style="align-items: center; justify-content: center; padding: 16px; z-index: 99999;" onclick="if(event.target===this) closeModal('orderCompletedModal')">
    <div class="modal-content" style="max-width: 420px; border-radius: 20px; border: 1px solid rgba(255, 255, 255, 0.12); padding: 22px 18px; text-align: center; margin: auto; box-shadow: 0 16px 40px rgba(0,0,0,0.8); background: #14100D; position: relative;">
      
      <!-- Close button in corner -->
      <button type="button" onclick="closeModal('orderCompletedModal')" aria-label="Close" style="position: absolute; top: 14px; right: 14px; background: rgba(255,255,255,0.06); border: 1px solid rgba(255,255,255,0.12); color: #C8B29E; border-radius: 50%; width: 32px; height: 32px; display: flex; align-items: center; justify-content: center; cursor: pointer; padding: 0; transition: all 0.15s;">
        <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><line x1="18" y1="6" x2="6" y2="18"></line><line x1="6" y1="6" x2="18" y2="18"></line></svg>
      </button>

      <!-- VIEW 1: Rating & Feedback Form -->
      <div id="custFeedbackFormView">
        <!-- Top Handed-Over Badge -->
        <div style="display: inline-flex; align-items: center; gap: 6px; background: rgba(255, 255, 255, 0.06); border: 1px solid rgba(255, 255, 255, 0.12); border-radius: 20px; padding: 4px 12px; margin-bottom: 10px;">
          <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="#D4AF37" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"></polyline></svg>
          <span style="font-size: 11px; font-weight: 700; letter-spacing: 0.8px; text-transform: uppercase; color: #E2DBD4;">Order Handed Over</span>
        </div>

        <div class="modal-title" id="completedModalOrderNum" style="font-size: 32px; font-family: 'Cinzel', serif; font-weight: 800; color: #FFFFFF; letter-spacing: 1px; line-height: 1.1;">#1</div>
        <div id="completedModalTableInfo" style="font-size: 12px; font-weight: 600; color: #A89B91; margin-top: 3px;">Table 1 • Dine-In</div>

        <!-- Rating Prompt -->
        <div style="font-size: 15px; font-weight: 700; color: #FFFFFF; margin-top: 12px; font-family: 'Outfit', sans-serif;">
          How was your celestial experience?
        </div>
        <div style="font-size: 12px; color: #9E9187; margin-top: 2px;">
          Your order is served & ready to enjoy. Tap a star to rate your visit!
        </div>

        <!-- 5 Star Interactive Rating -->
        <div style="margin: 10px 0 2px 0;">
          <div id="custStarRow" class="cust-star-row"></div>
          <div id="custRatingDescriptor" class="cust-rating-descriptor">
            ⭐⭐⭐⭐⭐ Exceptional & Delicious!
          </div>
        </div>

        <!-- Quick Compliment / Suggestion Chips -->
        <div style="margin-top: 12px; text-align: left;">
          <div style="font-size: 10.5px; font-weight: 700; text-transform: uppercase; letter-spacing: 0.8px; color: #A89B91; margin-bottom: 6px; display: flex; align-items: center; gap: 5px;">
            <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="#D4AF37" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2"></polygon></svg>
            <span>Tap to Select Highlights / Suggestions:</span>
          </div>
          <div id="custFeedbackChipsContainer" style="display: flex; flex-wrap: wrap; gap: 6px;">
            <button type="button" class="cust-fb-chip active" onclick="toggleFeedbackChip(this, 'Delicious Coffee & Drinks')">☕ Delicious Coffee</button>
            <button type="button" class="cust-fb-chip active" onclick="toggleFeedbackChip(this, 'Fast & Friendly Service')">⚡ Fast Service</button>
            <button type="button" class="cust-fb-chip" onclick="toggleFeedbackChip(this, 'Friendly Barista')">✨ Friendly Baristas</button>
            <button type="button" class="cust-fb-chip" onclick="toggleFeedbackChip(this, 'Great Presentation')">🍰 Great Presentation</button>
            <button type="button" class="cust-fb-chip" onclick="toggleFeedbackChip(this, 'Cozy Atmosphere')">🌿 Cozy Atmosphere</button>
            <button type="button" class="cust-fb-chip" onclick="toggleFeedbackChip(this, 'Spotless & Clean')">🧼 Spotless & Clean</button>
          </div>
        </div>

        <!-- Suggestion / Message Textarea -->
        <div style="margin-top: 12px; text-align: left;">
          <div style="font-size: 10.5px; font-weight: 700; text-transform: uppercase; letter-spacing: 0.8px; color: #A89B91; margin-bottom: 5px; display: flex; justify-content: space-between;">
            <span>Message or Suggestion:</span>
            <span style="color: #6E5D53; font-weight: 600;">Optional</span>
          </div>
          <textarea id="custFeedbackMessageInput" class="cust-fb-textarea" rows="3" placeholder="Tell us what you loved or how we can make your next visit even better..."></textarea>
        </div>

        <!-- Actions: Submit Only -->
        <div style="margin-top: 16px;">
          <button type="button" id="btnSubmitFeedback" onclick="submitCustomerFeedback()" style="width: 100%; background: #D4AF37; border: none; color: #110E0C; border-radius: 12px; padding: 13px 16px; font-weight: 800; font-size: 14px; cursor: pointer; display: flex; align-items: center; justify-content: center; gap: 8px; box-shadow: none; transition: background 0.15s ease;">
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><line x1="22" y1="2" x2="11" y2="13"></line><polygon points="22 2 15 22 11 13 2 9 22 2"></polygon></svg>
            <span id="btnSubmitFeedbackText">Submit Feedback & Rating</span>
          </button>
        </div>
      </div>

      <!-- VIEW 2: Thank You / Success View -->
      <div id="custFeedbackSuccessView" style="display: none; padding: 14px 4px;">
        <div style="width: 56px; height: 56px; border-radius: 50%; background: rgba(34,197,94,0.12); border: 1.5px solid #22C55E; display: flex; align-items: center; justify-content: center; margin: 0 auto 14px auto; color: #22C55E; box-shadow: none;">
          <svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"></polyline></svg>
        </div>

        <div style="font-size: 11px; font-weight: 700; letter-spacing: 1.5px; text-transform: uppercase; color: #22C55E; margin-bottom: 4px;">Feedback Saved</div>
        <div class="modal-title" style="font-size: 20px; font-family: 'Cinzel', serif; font-weight: 800; color: #FFFFFF; letter-spacing: 0.5px;">Thank You!</div>
        
        <div style="font-size: 12.5px; color: #A89B91; line-height: 1.5; margin-top: 10px; padding: 12px 14px; background: rgba(255,255,255,0.03); border-radius: 12px; border: 1px solid rgba(255, 255, 255, 0.08);">
          Your rating and feedback have been sent to the barista team. We appreciate your visit!
        </div>

        <div style="margin-top: 18px;">
          <button type="button" onclick="closeModal('orderCompletedModal');" style="width: 100%; background: #D4AF37; border: none; color: #110E0C; border-radius: 12px; padding: 12px; font-weight: 800; font-size: 13.5px; cursor: pointer; display: flex; align-items: center; justify-content: center; gap: 8px;">
            <span>Done</span>
          </button>
        </div>
      </div>

    </div>
  </div>

  <!-- Live Kitchen Activity Pop-Up Modal -->
  <div class="modal-overlay" id="kitchenQueueModal" onclick="if(event.target===this) closeModal('kitchenQueueModal')">
    <div class="modal-content" style="max-width: 480px; margin: 0 auto; border: 1px solid rgba(255, 255, 255, 0.12); border-radius: 20px; box-shadow: 0 16px 40px rgba(0,0,0,0.7); background: #14100D;">
      <div class="modal-drag-pill"></div>
      
      <div style="display: flex; justify-content: space-between; align-items: flex-start; margin-bottom: 14px;">
        <div>
          <div class="modal-title" style="display: flex; align-items: center; gap: 8px; font-size: 18px;">
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="color: #C48248;"><path d="M18 8h1a4 4 0 0 1 0 8h-1"></path><path d="M2 8h16v9a4 4 0 0 1-4 4H6a4 4 0 0 1-4-4V8z"></path><line x1="6" y1="1" x2="6" y2="4"></line><line x1="10" y1="1" x2="10" y2="4"></line><line x1="14" y1="1" x2="14" y2="4"></line></svg>
            <span>Live Kitchen Activity</span>
          </div>
          <div class="modal-desc" style="margin-bottom: 0; color: var(--text-muted); font-size: 12px; margin-top: 2px;">Real-time preparation queue from the barista bar & kitchen</div>
        </div>
        <div style="display: flex; align-items: center; gap: 8px;">
          <button onclick="refreshLiveQueueModal()" title="Refresh Queue" style="background: rgba(255,255,255,0.06); border: 1px solid rgba(255,255,255,0.12); border-radius: 50%; width: 30px; height: 30px; font-size: 13px; color: #E5E0DA; cursor: pointer; display: flex; align-items: center; justify-content: center; transition: all 0.2s;">
            <svg id="queueRefreshIcon" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M21.5 2v6h-6M21.34 15.57a10 10 0 1 1-.57-8.38l5.67-5.67"/></svg>
          </button>
          <div style="display: flex; align-items: center; gap: 5px; background: rgba(255,255,255,0.06); border: 1px solid rgba(255,255,255,0.12); border-radius: 12px; padding: 3px 8px; font-size: 10px; font-weight: 700; color: #86EFAC;">
            <span style="width: 6px; height: 6px; border-radius: 50%; background: #22C55E; display: inline-block;"></span>
            <span>Live Sync</span>
          </div>
          <button onclick="closeModal('kitchenQueueModal')" style="background: rgba(255,255,255,0.06); border: none; border-radius: 50%; width: 30px; height: 30px; font-size: 13px; color: var(--text-muted); cursor: pointer; display: flex; align-items: center; justify-content: center;">✕</button>
        </div>
      </div>

      <!-- Active Tracked Order Highlight in Modal -->
      <div id="modalActiveOrderBanner" style="display: none;"></div>

      <!-- Now Brewing / Preparing Section -->
      <div style="background: rgba(255,255,255,0.03); border: 1px solid rgba(255,255,255,0.09); border-radius: 14px; padding: 14px; margin-bottom: 12px;">
        <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 10px;">
          <div style="font-size: 11.5px; font-weight: 800; color: #D97706; text-transform: uppercase; letter-spacing: 0.5px; display: flex; align-items: center; gap: 6px;">
            <span style="width: 6px; height: 6px; border-radius: 50%; background: #D97706; display: inline-block;"></span>
            <span>Now Brewing / Preparing</span>
          </div>
          <span id="modalNowPrepCount" style="font-size: 11px; font-weight: 700; color: #D4A373; background: rgba(255,255,255,0.05); border: 1px solid rgba(255,255,255,0.1); border-radius: 10px; padding: 2px 8px;">0 orders</span>
        </div>
        <div id="modalNowPreparingChips" style="display: flex; flex-wrap: wrap; gap: 8px; align-items: center; min-height: 34px;">
          <span style="font-size: 12px; color: var(--text-muted); font-style: italic;">No orders currently on bar</span>
        </div>
      </div>

      <!-- Orders in Queue Section -->
      <div style="background: rgba(255,255,255,0.02); border: 1px solid rgba(255,255,255,0.08); border-radius: 14px; padding: 14px; margin-bottom: 12px;">
        <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 10px;">
          <div style="font-size: 11.5px; font-weight: 800; color: #E5E0DA; text-transform: uppercase; letter-spacing: 0.5px; display: flex; align-items: center; gap: 6px;">
            <span>Orders In Queue</span>
          </div>
          <span id="modalInQueueCount" style="font-size: 11px; font-weight: 700; color: var(--text-muted); background: rgba(255,255,255,0.05); border: 1px solid rgba(255,255,255,0.1); border-radius: 10px; padding: 2px 8px;">0 orders</span>
        </div>
        <div id="modalInQueueChips" style="display: flex; flex-wrap: wrap; gap: 7px; align-items: center; min-height: 34px;">
          <span style="font-size: 12px; color: var(--text-muted);">Queue is currently clear</span>
        </div>
      </div>

      <!-- Ready for Pickup Section -->
      <div style="background: rgba(34, 197, 94, 0.05); border: 1px solid rgba(34, 197, 94, 0.18); border-radius: 14px; padding: 14px; margin-bottom: 16px;">
        <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 10px;">
          <div style="font-size: 11.5px; font-weight: 800; color: #22C55E; text-transform: uppercase; letter-spacing: 0.5px; display: flex; align-items: center; gap: 6px;">
            <span style="width: 6px; height: 6px; border-radius: 50%; background: #22C55E; display: inline-block;"></span>
            <span>Ready For Pickup</span>
          </div>
          <span id="modalReadyCount" style="font-size: 11px; font-weight: 700; color: #86EFAC; background: rgba(34, 197, 94, 0.1); border: 1px solid rgba(34, 197, 94, 0.22); border-radius: 10px; padding: 2px 8px;">0 ready</span>
        </div>
        <div id="modalReadyChips" style="display: flex; flex-wrap: wrap; gap: 7px; align-items: center; min-height: 32px;">
          <span style="font-size: 12px; color: var(--text-muted);">No orders at pickup counter</span>
        </div>
      </div>

      <button onclick="closeModal('kitchenQueueModal')" style="width: 100%; background: rgba(255,255,255,0.06); border: 1px solid rgba(255,255,255,0.14); color: #F5EFEB; border-radius: 14px; padding: 12px; font-weight: 700; font-size: 13.5px; cursor: pointer; transition: all 0.15s;">
        Close Kitchen Queue
      </button>
    </div>
  </div>

  <!-- Customer Turn Up Volume Pop-Up Modal -->
  <div class="modal-overlay" id="customerVolumeModal" onclick="if(event.target === this) handleCustVolumeAction('close')" style="display: none; position: fixed; top: 0; left: 0; width: 100vw; height: 100vh; height: 100dvh; min-height: 100%; align-items: center; justify-content: center; padding: 18px; z-index: 999999; box-sizing: border-box; -webkit-overflow-scrolling: touch;">
    <div class="modal-content" style="max-width: 410px; width: 100%; border-radius: 24px; border: 1px solid rgba(255, 255, 255, 0.14); background: #14100D; padding: 26px 20px; text-align: center; margin: auto; position: relative; box-shadow: 0 16px 48px rgba(0,0,0,0.85); animation: popIn 0.22s cubic-bezier(0.18, 0.89, 0.32, 1.28);">
      
      <!-- Close Button -->
      <button type="button" onclick="handleCustVolumeAction('close')" aria-label="Close" style="position: absolute; top: 14px; right: 14px; background: rgba(255,255,255,0.07); border: 1px solid rgba(255,255,255,0.12); color: #C8B29E; border-radius: 50%; width: 30px; height: 30px; display: flex; align-items: center; justify-content: center; cursor: pointer; padding: 0;">
        <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><line x1="18" y1="6" x2="6" y2="18"></line><line x1="6" y1="6" x2="18" y2="18"></line></svg>
      </button>

      <!-- Animated Center Speaker Icon -->
      <div id="custVolumeIconBox" style="width: 70px; height: 70px; border-radius: 50%; background: rgba(255,255,255,0.06); border: 1.5px solid var(--caramel-accent); display: flex; align-items: center; justify-content: center; margin: 0 auto 14px auto; color: var(--caramel-accent); box-shadow: none; transition: all 0.25s ease;">
        <svg id="custVolumeSvg" width="38" height="38" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round">
          <polygon points="11 5 6 9 2 9 2 15 6 15 11 19 11 5"></polygon>
          <path d="M19.07 4.93a10 10 0 0 1 0 14.14M15.54 8.46a5 5 0 0 1 0 7.07"></path>
        </svg>
      </div>

      <!-- Animated Equalizer Bars -->
      <div id="custVolumeEqualizer" style="display: flex; justify-content: center; align-items: flex-end; gap: 4px; height: 26px; margin-bottom: 12px;">
        <span class="vol-eq-bar" style="width: 4px; height: 10px; background: var(--caramel-accent); border-radius: 2px; animation: eqBounce 0.9s ease-in-out infinite;"></span>
        <span class="vol-eq-bar" style="width: 4px; height: 22px; background: #C8B29E; border-radius: 2px; animation: eqBounce 1.1s ease-in-out infinite 0.15s;"></span>
        <span class="vol-eq-bar" style="width: 4px; height: 16px; background: #FFFFFF; border-radius: 2px; animation: eqBounce 0.8s ease-in-out infinite 0.3s;"></span>
        <span class="vol-eq-bar" style="width: 4px; height: 24px; background: var(--caramel-accent); border-radius: 2px; animation: eqBounce 1.2s ease-in-out infinite 0.1s;"></span>
        <span class="vol-eq-bar" style="width: 4px; height: 14px; background: #C8B29E; border-radius: 2px; animation: eqBounce 0.95s ease-in-out infinite 0.25s;"></span>
      </div>

      <div id="custVolumeModalSubtitle" style="font-size: 10.5px; font-weight: 800; letter-spacing: 1.8px; text-transform: uppercase; color: var(--caramel-accent); margin-bottom: 5px;">
        LIVE ORDER ACTIVE • AUDIO READY
      </div>

      <div class="modal-title" id="custVolumeModalTitle" style="font-size: 21px; font-family: 'Cinzel', serif; font-weight: 800; color: #FFFFFF; letter-spacing: 0.5px; line-height: 1.25;">
        Please Turn Up Your Phone Volume
      </div>

      <div id="custVolumeModalDesc" style="font-size: 13px; color: var(--text-light); line-height: 1.5; margin-top: 10px; padding: 12px 14px; background: rgba(255,255,255,0.05); border-radius: var(--radius-md); border: 1px dashed rgba(255,255,255,0.15);">
        Please ensure your phone volume is turned <b>UP</b> so you will hear the live chime alert and voice announcement when your order is ready for pickup!
      </div>

      <!-- Volume Key Advice Box with iPhone Tip -->
      <div id="custVolumeKeyBox" style="margin-top: 14px; background: rgba(0,0,0,0.52); border: 1px dashed rgba(255,255,255,0.2); border-radius: 16px; padding: 14px 12px; user-select: none;">
        <div style="display: flex; justify-content: center; align-items: center; gap: 8px; margin-bottom: 6px;">
          <div style="display: inline-flex; align-items: center; gap: 6px; background: rgba(255,255,255,0.08); border: 1px solid rgba(255,255,255,0.15); border-radius: 8px; padding: 6px 14px; color: #FFFFFF; font-size: 12px; font-weight: 800; letter-spacing: 0.5px;">
            <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polygon points="11 5 6 9 2 9 2 15 6 15 11 19 11 5"></polygon><path d="M15.54 8.46a5 5 0 0 1 0 7.07"></path><path d="M19.07 4.93a10 10 0 0 1 0 14.14"></path></svg>
            <span>DEVICE VOLUME UP</span>
          </div>
        </div>
        <div style="font-size: 12px; font-weight: 600; color: #FFFFFF; line-height: 1.4;">
          Turn up your phone volume, then tap below to test sound and enable audio.
        </div>
        <div style="margin-top: 8px; font-size: 11.5px; color: #FFB74D; background: rgba(255,183,77,0.12); border: 1px solid rgba(255,183,77,0.25); border-radius: 8px; padding: 6px 10px; display: flex; align-items: center; justify-content: center; gap: 6px;">
          <span>📱</span>
          <span><b>iPhone Users:</b> Switch side <b>Silent/Mute</b> switch <b>OFF</b> to hear alerts!</span>
        </div>
      </div>

      <!-- Okay / Test Sound Confirmation Button -->
      <button type="button" onclick="handleCustVolumeAction('button')" id="btnCustVolumeConfirm" style="margin-top: 15px; width: 100%; background: var(--caramel-accent); color: #110E0C; border: none; border-radius: var(--radius-md); padding: 14px 18px; font-weight: 800; font-size: 14.5px; cursor: pointer; display: flex; align-items: center; justify-content: center; gap: 8px; box-shadow: 0 4px 14px rgba(0,0,0,0.3); transition: all 0.15s ease;">
        <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polygon points="11 5 6 9 2 9 2 15 6 15 11 19 11 5"></polygon><path d="M19.07 4.93a10 10 0 0 1 0 14.14M15.54 8.46a5 5 0 0 1 0 7.07"></path></svg>
        <span>Test Sound & Confirm Volume</span>
      </button>
    </div>
  </div>

  <script>
    /*__INITIAL_MENU_DATA__*/
    /*__TABLE_AUTH_DATA__*/

    // ── Safe Storage Polyfill ────────────────────────────────────────────────
    // Tries localStorage first (best persistence), then sessionStorage (tab-scoped),
    // then falls back to a plain in-memory object (Safari Private / restricted envs).
    const _store = (() => {
      try {
        localStorage.setItem('__celestial_test__', '1');
        localStorage.removeItem('__celestial_test__');
        return localStorage;
      } catch (_) {
        try {
          sessionStorage.setItem('__celestial_test__', '1');
          sessionStorage.removeItem('__celestial_test__');
          return sessionStorage;
        } catch (_2) {
          const _mem = {};
          return {
            getItem(k) { return Object.prototype.hasOwnProperty.call(_mem, k) ? _mem[k] : null; },
            setItem(k, v) { _mem[k] = String(v); },
            removeItem(k) { delete _mem[k]; },
            get length() { return Object.keys(_mem).length; },
            key(i) { return Object.keys(_mem)[i] || null; }
          };
        }
      }
    })();
    // ────────────────────────────────────────────────────────────────────────

    const _tableAuth = window.TABLE_AUTH || { hasTableAttempt: false, isVerified: false, tableNumber: null, token: null };

    // Dynamic Liquid Glass Header Scroll Listener
    const initCustomerHeaderScroll = () => {
      const hdr = document.querySelector('header');
      if (!hdr) return;
      let ticking = false;
      window.addEventListener('scroll', () => {
        if (!ticking) {
          window.requestAnimationFrame(() => {
            if (window.scrollY > 10) {
              hdr.classList.add('scrolled');
            } else {
              hdr.classList.remove('scrolled');
            }
            ticking = false;
          });
          ticking = true;
        }
      }, { passive: true });
      if (window.scrollY > 10) hdr.classList.add('scrolled');
    };
    initCustomerHeaderScroll();
    let isTableVerified = Boolean(_tableAuth.isVerified);
    let currentTable = _tableAuth.isVerified ? _tableAuth.tableNumber : null;
    let currentTableToken = _tableAuth.isVerified ? _tableAuth.token : null;
    let unverifiedTableAttempt = (!_tableAuth.isVerified && _tableAuth.hasTableAttempt) ? _tableAuth.tableNumber : null;

    if (!isTableVerified && !_tableAuth.hasTableAttempt) {
      try {
        const sTable = _store.getItem('celestial_verified_table');
        const sToken = _store.getItem('celestial_verified_token');
        if (sTable && sToken) {
          currentTable = sTable;
          currentTableToken = sToken;
          isTableVerified = true;
        }
      } catch(_) {}
    } else if (isTableVerified && currentTable && currentTableToken) {
      try {
        _store.setItem('celestial_verified_table', currentTable);
        _store.setItem('celestial_verified_token', currentTableToken);
        _store.setItem('celestial_customer_table', currentTable);
      } catch(_) {}
    } else if (_tableAuth.hasTableAttempt && !_tableAuth.isVerified) {
      // User specifically modified URL to unverified table: clear stored table to prevent impersonation
      try {
        _store.removeItem('celestial_customer_table');
        _store.removeItem('celestial_verified_table');
        _store.removeItem('celestial_verified_token');
      } catch(_) {}
    }

    let menuData = window.INITIAL_MENU || [];
    let cart = [];
    let activeCategory = 'all';
    let currentSearch = '';
    let selectedItem = null;
    let selectedCustomizations = [];
    let selectedPayment = 'cash';
    let modalItemQty = 1;
    let activeTrackedOrderId = null;
    let activeTrackedOrderNum = null;
    let prevTrackStatus = '';
    let alarmInterval = null;
    let isAlarmRunning = false;
    let isAlarmPermanentlyDismissed = false;
    let dismissedOrderNumber = null;
    let dismissedOrderId = null;
    let alarmMasterGainNode = null;
    let activeAlarmOscillators = [];
    let fallbackChimeTimeout = null;
    let ttsVoiceTimeout = null;
    let ttsWatchdogTimeout = null;
    let ttsKeepAliveInterval = null;
    let activeSpeechUtterance = null;
    let alarmLoopTimeout = null;
    let currentAlarmAudio = null;
    let audioContext = null;

    // Clear any stale dismiss flags from past sessions so first orders are never blocked
    try {
      _store.removeItem('alarmDismissed_global');
      _store.removeItem('alarmDismissed_1');
      _store.removeItem('alarmDismissed_#1');
      _store.removeItem('custVolumeSeen_current');
      _store.removeItem('custVolumeSeen_active_order');
      _store.removeItem('custVolumeSeen_1');
      _store.removeItem('custPaymentVolumeSeen_current');
      _store.removeItem('custPaymentVolumeSeen_active_order');
      _store.removeItem('custPaymentVolumeSeen_1');
      try {
        sessionStorage.removeItem('custPaymentVolumeSeen_current');
        sessionStorage.removeItem('custPaymentVolumeSeen_active_order');
      } catch(_ss) {}
    } catch(_) {}

    function isOrderAlarmDismissed() {
      const currentNum = activeTrackedOrderNum || _store.getItem('activeOrderNum') || '';
      const currentId = activeTrackedOrderId || _store.getItem('activeOrderId') || '';
      const cleanNum = String(currentNum).replace('#', '').trim();
      const cleanId = String(currentId).replace('#', '').trim();

      if (cleanNum && dismissedOrderNumber && (cleanNum === dismissedOrderNumber || currentNum === dismissedOrderNumber)) return true;
      if (cleanId && dismissedOrderId && (cleanId === dismissedOrderId || currentId === dismissedOrderId)) return true;

      if (cleanNum && (_store.getItem('alarmDismissed_' + cleanNum) === 'true' || _store.getItem('alarmDismissed_#' + cleanNum) === 'true')) return true;
      if (cleanId && _store.getItem('alarmDismissed_' + cleanId) === 'true') return true;

      if (!cleanNum && !cleanId) return isAlarmPermanentlyDismissed;

      return false;
    }
    let custWs = null;
    let pollInterval = null;
    let isCustVolumeModalOpen = false;
    let isCustVolumeDismissing = false;
    let activeReceiptData = null;
    try {
      const savedReceipt = _store.getItem('activeReceiptData');
      if (savedReceipt) activeReceiptData = JSON.parse(savedReceipt);
    } catch(e) {}

    const categoryLabels = {
      all: 'All Menu Items',
      coffee: 'Coffee & Espresso',
      nonEspresso: 'Non-Coffee Specialties',
      milktea: 'Milk Tea & Boba',
      frappe: 'Ice Blended Frappes',
      cheesecakeSeries: 'Cheesecake Slices',
      streetBites: 'Street Food & Bites',
      pastaDishes: 'Pastas & Noodles',
      sandwich: 'Sandwiches & Snacks',
      dinner: 'Dinner & Rice Meals'
    };

    function getUrlParamsInfo() {
      const p = new URLSearchParams(window.location.search);
      let table = p.get('table') || p.get('t');
      let token = p.get('token') || p.get('key') || p.get('code');
      let order = p.get('order') || p.get('orderId') || p.get('id') || p.get('num');

      // Check path parts e.g. /table/T1-C7E30D12, /table/2, /order/3
      const pathParts = window.location.pathname.split('/').filter(Boolean);
      for (let i = 0; i < pathParts.length; i++) {
        const part = pathParts[i];
        const lower = part.toLowerCase();
        if ((lower === 'table' || lower === 't') && pathParts[i + 1]) {
          table = pathParts[i + 1];
        } else if (lower.startsWith('table') && lower.length > 5) {
          table = part.substring(5);
        } else if ((lower === 'order' || lower === 'track' || lower === 'status') && pathParts[i + 1]) {
          order = pathParts[i + 1];
        }
      }

      let cleanNum = null;
      if (table) {
        const s = String(table).trim();
        if (s.includes('-') || s.includes('_')) {
          const parts = s.split(/[-_]/);
          cleanNum = parts[0].replace(/[^0-9]/g, '');
          if (!token && parts.length > 1) {
            token = parts.slice(1).join('-');
          }
        } else {
          cleanNum = s.replace(/[^0-9]/g, '');
        }
      }

      const cleanTable = cleanNum ? ('Table ' + cleanNum) : null;
      return {
        table: cleanTable,
        rawTable: cleanNum,
        fullTableCode: table ? String(table).trim() : null,
        token: token ? String(token).trim() : null,
        order: order ? String(order).trim().replace('#', '') : null
      };
    }

    let currentOrderType = (isTableVerified && currentTable) ? 'dineIn' : 'takeaway';
    const urlParams = new URLSearchParams(window.location.search);
    const typeParam = urlParams.get('type') || urlParams.get('orderType');
    if (typeParam === 'takeaway' || typeParam === 'takeout' || typeParam === 'togo') {
      currentOrderType = 'takeaway';
    } else if ((typeParam === 'dinein' || typeParam === 'dineIn') && isTableVerified) {
      currentOrderType = 'dineIn';
    } else {
      try {
        const savedType = _store.getItem('celestial_order_type');
        if (savedType === 'takeaway' || (savedType === 'dineIn' && isTableVerified)) {
          currentOrderType = savedType;
        }
      } catch(e) {}
    }

    function showUnverifiedTableModal(tableName) {
      const modal = document.getElementById('unverifiedTableModal');
      const titleEl = document.getElementById('unverifiedTableTitle');
      const bodyEl = document.getElementById('unverifiedTableBody');
      const name = tableName || 'this table';

      // Completely hide menu & order UI
      const controls = document.getElementById('controlsWrapper');
      const menu = document.getElementById('menuView');
      const cartB = document.getElementById('cartBar');
      const tracker = document.getElementById('trackerView');
      if (controls) controls.style.display = 'none';
      if (menu) menu.style.display = 'none';
      if (cartB) cartB.style.display = 'none';
      if (tracker) tracker.style.display = 'none';

      if (titleEl) titleEl.innerText = 'Menu Access to ' + name + ' Blocked';
      if (bodyEl) {
        bodyEl.innerHTML = 'Every table at Celestial Cafe has its own <b>unique physical QR link and security code</b>.<br><br>You cannot access the menu for <b>' + name + '</b> by editing or typing the link in your browser.<br><br>To unlock and view the menu, please <b>scan the physical QR code</b> located on ' + name + ' with your phone camera.';
      }
      if (modal) modal.style.display = 'flex';
      try {
        if (navigator.vibrate) navigator.vibrate([100, 50, 100]);
      } catch(_) {}
    }

    function updateOrderTypeHeaderPill() {
      const pill = document.getElementById('tablePill');
      if (!pill) return;
      pill.style.cursor = 'pointer';
      pill.style.pointerEvents = 'auto';
      pill.onclick = showDiningOptionModal;
      if (currentOrderType === 'takeaway' || !isTableVerified || !currentTable) {
        pill.className = 'table-pill takeout';
        pill.title = 'Take Out - Tap to change to Dine-In';
        pill.innerHTML = '<svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="color: var(--gold-light); vertical-align: -1px; margin-right: 3px;"><path d="M6 2L3 6v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2V6l-3-4z"></path><line x1="3" y1="6" x2="21" y2="6"></line><path d="M16 10a4 4 0 0 1-8 0"></path></svg><span id="tablePillLabel">Take Out</span><svg width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" style="opacity: 0.7; margin-left: 2px;"><polyline points="6 9 12 15 18 9"></polyline></svg>';
      } else {
        pill.className = 'table-pill';
        const displayLabel = currentTable || 'Dine-In';
        pill.title = displayLabel + ' - Tap to change to Take Out';
        pill.innerHTML = `<svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="color: var(--gold-light); vertical-align: -1px; margin-right: 3px;"><path d="M3 2v7c0 1.1.9 2 2 2h4a2 2 0 0 0 2-2V2"></path><path d="M7 2v20"></path><path d="M21 15V2v0a5 5 0 0 0-5 5v6c0 1.1.9 2 2 2h3Zm0 0v7"></path></svg><span id="tablePillLabel">\${displayLabel}</span><svg width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" style="opacity: 0.7; margin-left: 2px;"><polyline points="6 9 12 15 18 9"></polyline></svg>`;
      }
      _updateTrayDiningUI();
    }

    function _updateTrayDiningUI() {
      const dineInBanner = document.getElementById('trayDineInBanner');
      const takeoutBanner = document.getElementById('trayTakeoutBanner');
      const dineInTableText = document.getElementById('trayDineInTableText');
      const custInput = document.getElementById('custNameInput');

      if (dineInTableText) {
        dineInTableText.innerText = (isTableVerified && currentTable)
            ? `\${currentTable} (Dine-In at Table)`
            : 'Dine-In (Physical QR Scan Required)';
      }

      if (currentOrderType === 'takeaway' || !isTableVerified || !currentTable) {
        if (dineInBanner) dineInBanner.style.display = 'none';
        if (takeoutBanner) takeoutBanner.style.display = 'flex';
        if (custInput) custInput.placeholder = 'Enter name for pickup (e.g. Maria)';
      } else {
        if (dineInBanner) dineInBanner.style.display = 'flex';
        if (takeoutBanner) takeoutBanner.style.display = 'none';
        if (custInput) custInput.placeholder = 'Enter your name (e.g. Maria, John)';
      }
    }

    function setOrderType(type, save = true) {
      if (type === 'dineIn' && (!isTableVerified || !currentTable)) {
        showUnverifiedTableModal(unverifiedTableAttempt || 'Table');
        return;
      }
      currentOrderType = type;
      if (save) {
        try {
          _store.setItem('celestial_order_type', type);
          sessionStorage.setItem('celestial_dining_chosen', 'true');
        } catch(e) {}
      }
      updateOrderTypeHeaderPill();
      _updateDiningModalUI();
    }

    function showDiningOptionModal() {
      _updateDiningModalUI();
      const modal = document.getElementById('diningOptionModal');
      if (modal) modal.style.display = 'flex';
    }

    function selectDiningOption(type) {
      if (type === 'dineIn' && (!isTableVerified || !currentTable)) {
        showUnverifiedTableModal(unverifiedTableAttempt || 'Table');
        return;
      }
      setOrderType(type, true);
    }

    function confirmDiningOptionAndClose() {
      if (currentOrderType === 'dineIn' && (!isTableVerified || !currentTable)) {
        showUnverifiedTableModal(unverifiedTableAttempt || 'Table');
        return;
      }
      closeModal('diningOptionModal');
      try {
        _store.setItem('celestial_order_type', currentOrderType);
        sessionStorage.setItem('celestial_dining_chosen', 'true');
      } catch(e) {}
      updateOrderTypeHeaderPill();
    }

    function _updateDiningModalUI() {
      const cardDineIn = document.getElementById('cardDineIn');
      const cardTakeout = document.getElementById('cardTakeout');
      const dineInCheck = document.getElementById('dineInCheck');
      const takeoutCheck = document.getElementById('takeoutCheck');
      const welcomeTableEl = document.getElementById('welcomeScannedTable');
      const welcomeTableBadge = document.getElementById('welcomeTableBadge');

      if (isTableVerified && currentTable) {
        if (welcomeTableEl) welcomeTableEl.innerText = currentTable;
        if (welcomeTableBadge) {
          welcomeTableBadge.innerHTML = '<span style="background:rgba(40,140,120,0.18);border:1px solid rgba(40,140,120,0.4);color:#6FE0AC;font-size:10px;font-weight:800;padding:2px 7px;border-radius:5px;display:inline-flex;align-items:center;gap:3px;white-space:nowrap;">✓ Verified QR</span>';
        }
        if (cardDineIn) cardDineIn.style.opacity = '1';
      } else {
        if (welcomeTableEl) welcomeTableEl.innerText = 'No Table Scanned';
        if (welcomeTableBadge) {
          welcomeTableBadge.innerHTML = '<span style="background:rgba(255,255,255,0.06);border:1px solid rgba(255,255,255,0.12);color:#D6C8BD;font-size:9.5px;font-weight:700;padding:2px 6px;border-radius:5px;white-space:nowrap;">Scan QR to Dine-In</span>';
        }
        if (cardDineIn) cardDineIn.style.opacity = '0.7';
      }

      if (currentOrderType === 'takeaway' || !isTableVerified || !currentTable) {
        if (cardDineIn) cardDineIn.classList.remove('selected');
        if (cardTakeout) cardTakeout.classList.add('selected');
        if (dineInCheck) dineInCheck.style.display = 'none';
        if (takeoutCheck) takeoutCheck.style.display = 'inline';
      } else {
        if (cardDineIn) cardDineIn.classList.add('selected');
        if (cardTakeout) cardTakeout.classList.remove('selected');
        if (dineInCheck) dineInCheck.style.display = 'inline';
        if (takeoutCheck) takeoutCheck.style.display = 'none';
      }
    }

    updateOrderTypeHeaderPill();

    // Vibration Strategy
    let vibrateLoop = null;

    function doVibrate() {
      try {
        if (navigator.vibrate) {
          navigator.vibrate([600, 200, 600, 200, 1000]);
        }
      } catch(e) {}
    }

    function startVibrationLoop() {
      doVibrate();
      if (!vibrateLoop) {
        vibrateLoop = setInterval(doVibrate, 2000);
      }
    }

    function stopVibrationLoop() {
      if (vibrateLoop) {
        clearInterval(vibrateLoop);
        vibrateLoop = null;
      }
      try {
        if (navigator.vibrate) navigator.vibrate(0);
      } catch(e) {}
    }

    let audioUnlocked = false;
    let fallbackChimeDataUri = null;

    function getFallbackChimeUri() {
      if (fallbackChimeDataUri) return fallbackChimeDataUri;
      try {
        const sampleRate = 11025;
        const duration = 0.95;
        const numSamples = Math.floor(sampleRate * duration);
        const headerLength = 44;
        const totalLength = headerLength + numSamples;
        const buffer = new Uint8Array(totalLength);
        buffer[0] = 0x52; buffer[1] = 0x49; buffer[2] = 0x46; buffer[3] = 0x46; // RIFF
        const fileSize = totalLength - 8;
        buffer[4] = fileSize & 0xff; buffer[5] = (fileSize >> 8) & 0xff;
        buffer[6] = (fileSize >> 16) & 0xff; buffer[7] = (fileSize >> 24) & 0xff;
        buffer[8] = 0x57; buffer[9] = 0x41; buffer[10] = 0x56; buffer[11] = 0x45; // WAVE
        buffer[12] = 0x66; buffer[13] = 0x6d; buffer[14] = 0x74; buffer[15] = 0x20; // fmt
        buffer[16] = 16; buffer[17] = 0; buffer[18] = 0; buffer[19] = 0;
        buffer[20] = 1; buffer[21] = 0; // PCM
        buffer[22] = 1; buffer[23] = 0; // Mono
        buffer[24] = sampleRate & 0xff; buffer[25] = (sampleRate >> 8) & 0xff;
        buffer[26] = 0; buffer[27] = 0;
        buffer[28] = sampleRate & 0xff; buffer[29] = (sampleRate >> 8) & 0xff;
        buffer[30] = 0; buffer[31] = 0;
        buffer[32] = 1; buffer[33] = 0;
        buffer[34] = 8; buffer[35] = 0; // 8-bit
        buffer[36] = 0x64; buffer[37] = 0x61; buffer[38] = 0x74; buffer[39] = 0x61; // data
        buffer[40] = numSamples & 0xff; buffer[41] = (numSamples >> 8) & 0xff;
        buffer[42] = 0; buffer[43] = 0;
        
        const notes = [
          { freq: 1046.50, start: 0.00, len: 0.35, amp: 0.40 },
          { freq: 1318.51, start: 0.14, len: 0.35, amp: 0.45 },
          { freq: 1567.98, start: 0.28, len: 0.40, amp: 0.50 },
          { freq: 2093.00, start: 0.42, len: 0.52, amp: 0.55 }
        ];

        for (let i = 0; i < numSamples; i++) {
          const t = i / sampleRate;
          let sample = 0;
          for (let n = 0; n < notes.length; n++) {
            const nt = notes[n];
            if (t >= nt.start && t < nt.start + nt.len) {
              const dt = t - nt.start;
              const decay = Math.max(0, 1 - (dt / nt.len));
              sample += Math.sin(2 * Math.PI * nt.freq * dt) * decay * nt.amp;
              sample += Math.sin(2 * Math.PI * nt.freq * 2 * dt) * decay * (nt.amp * 0.22);
            }
          }
          sample = Math.max(-1, Math.min(1, sample));
          buffer[headerLength + i] = Math.floor((sample + 1) * 127.5);
        }
        let binary = '';
        for (let i = 0; i < buffer.length; i++) {
          binary += String.fromCharCode(buffer[i]);
        }
        fallbackChimeDataUri = 'data:audio/wav;base64,' + btoa(binary);
      } catch(e) {}
      return fallbackChimeDataUri;
    }

    let _ttsPrimed = false;
    function _primeSpeechSynthesis() {
      if (_ttsPrimed) return;
      _ttsPrimed = true;
      try {
        if ('speechSynthesis' in window) {
          if (window.speechSynthesis.paused) {
            try { window.speechSynthesis.resume(); } catch(_) {}
          }
          window.speechSynthesis.getVoices();
          // Prime iOS Safari WebKit speech synthesis
          const primeUtter = new SpeechSynthesisUtterance(' ');
          primeUtter.volume = 0.01;
          window.speechSynthesis.speak(primeUtter);
        }
      } catch(_) {}
    }

    function isIPhoneOrIOS() {
      const ua = navigator.userAgent || navigator.vendor || window.opera || '';
      return /iPhone|iPad|iPod/i.test(ua) || (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);
    }

    let _voiceBuffer = null;
    let _voiceAudioLoading = false;
    function loadVoiceAudio() {
      if (isIPhoneOrIOS()) return; // iPhone uses repeating chime alarm only, no TTS
      if (_voiceBuffer || _voiceAudioLoading) return;
      _voiceAudioLoading = true;
      try {
        fetch('/audio/order-ready.wav')
          .then(r => {
            if (!r.ok) throw new Error('Audio load status ' + r.status);
            return r.arrayBuffer();
          })
          .then(buf => {
            if (!audioContext) {
              const AC = window.AudioContext || window.webkitAudioContext;
              if (AC) audioContext = new AC();
            }
            if (audioContext) {
              audioContext.decodeAudioData(buf, (decoded) => {
                _voiceBuffer = decoded;
                _voiceAudioLoading = false;
              }, () => { _voiceAudioLoading = false; });
            } else {
              _voiceAudioLoading = false;
            }
          })
          .catch(() => { _voiceAudioLoading = false; });
      } catch(_) {
        _voiceAudioLoading = false;
      }
    }

    function initAudio() {
      _primeSpeechSynthesis();
      loadVoiceAudio();
      try {
        if (!audioContext) {
          const AudioContextClass = window.AudioContext || window.webkitAudioContext;
          if (AudioContextClass) audioContext = new AudioContextClass();
        }
        if (audioContext && audioContext.state === 'suspended') {
          return audioContext.resume().then(() => {
            audioUnlocked = true;
            _startAudioKeepAlive();
            updateSoundStatusBadge(true);
          }).catch(() => {});
        } else if (audioContext && audioContext.state === 'running') {
          audioUnlocked = true;
          _startAudioKeepAlive();
          updateSoundStatusBadge(true);
        }
      } catch(e) {}
      return Promise.resolve();
    }

    function testOrEnableSound(e) {
      if (e) e.stopPropagation();
      isAlarmPermanentlyDismissed = false;
      dismissedOrderNumber = null;
      dismissedOrderId = null;
      _unlockAudioOnGesture();
      _primeSpeechSynthesis();
      isAlarmRunning = true;
      playAlarmSound();
      setTimeout(() => { isAlarmRunning = false; }, 1200);
    }

    function updateSoundStatusBadge() {}

    // Auto-unlock AudioContext and maintain active iOS Safari audio session
    let _audioKeepAliveSource = null;
    function _startAudioKeepAlive() {
      if (_audioKeepAliveSource || !audioContext) return;
      try {
        const buffer = audioContext.createBuffer(1, 22050, 22050);
        const source = audioContext.createBufferSource();
        source.buffer = buffer;
        source.loop = true;
        const gain = audioContext.createGain();
        gain.gain.value = 0.001; // Non-zero so iOS Safari registers active media session, but 100% dead silent buffer
        source.connect(gain);
        gain.connect(audioContext.destination);
        source.start(0);
        _audioKeepAliveSource = source;
      } catch(_) {}
    }

    function _unlockAudioOnGesture() {
      _primeSpeechSynthesis();
      try {
        if (!audioContext) {
          const AC = window.AudioContext || window.webkitAudioContext;
          if (AC) audioContext = new AC();
        }
        if (audioContext) {
          if (audioContext.state === 'suspended') {
            audioContext.resume().then(() => {
              _startAudioKeepAlive();
            }).catch(() => {});
          } else if (audioContext.state === 'running') {
            _startAudioKeepAlive();
          }
        }
        audioUnlocked = true;
      } catch(e) {}
    }
    ['click','touchstart','touchend','keydown','pointerdown']
      .forEach(ev => document.addEventListener(ev, _unlockAudioOnGesture, { once: false, passive: true }));

    // iOS WebKit background resume & wake handlers
    document.addEventListener('visibilitychange', () => {
      if (document.visibilityState === 'visible') {
        if (audioContext && audioContext.state === 'suspended') {
          audioContext.resume().catch(() => {});
        }
        if (activeTrackedOrderId || activeTrackedOrderNum) {
          checkOrderStatus();
        }
      }
    });
    window.addEventListener('pageshow', () => {
      if (audioContext && audioContext.state === 'suspended') {
        audioContext.resume().catch(() => {});
      }
      if (activeTrackedOrderId || activeTrackedOrderNum) {
        checkOrderStatus();
      }
    });

    function playAlarmSound() {
      if (!isAlarmRunning) return;
      if (fallbackChimeTimeout) {
        clearTimeout(fallbackChimeTimeout);
        fallbackChimeTimeout = null;
      }

      try {
        if (!audioContext) initAudio();
        if (audioContext) {
          // Dedicated master gain node for clean, instantaneous muting
          if (!alarmMasterGainNode) {
            try {
              alarmMasterGainNode = audioContext.createGain();
              alarmMasterGainNode.connect(audioContext.destination);
            } catch(_) {}
          }

          const doSynth = () => {
            if (!audioContext || !isAlarmRunning) return;
            try {
              const now = audioContext.currentTime;
              if (alarmMasterGainNode) {
                alarmMasterGainNode.gain.cancelScheduledValues(now);
                alarmMasterGainNode.gain.setValueAtTime(1.0, now);
              }

              // 4-tone crystalline cafe chime: C6 -> E6 -> G6 -> C7
              const chordNotes = [
                { freq: 1046.50, time: 0.00, dur: 0.35, vol: 0.70 },
                { freq: 1318.51, time: 0.14, dur: 0.35, vol: 0.75 },
                { freq: 1567.98, time: 0.28, dur: 0.40, vol: 0.80 },
                { freq: 2093.00, time: 0.42, dur: 0.55, vol: 0.85 }
              ];

              chordNotes.forEach(n => {
                if (!isAlarmRunning) return;
                const startT = now + n.time;
                const endT = startT + n.dur;

                // Primary pure sine wave tone
                const osc1 = audioContext.createOscillator();
                const gain1 = audioContext.createGain();
                osc1.type = 'sine';
                osc1.frequency.setValueAtTime(n.freq, startT);
                gain1.gain.setValueAtTime(n.vol, startT);
                gain1.gain.exponentialRampToValueAtTime(0.001, endT);
                osc1.connect(gain1);
                if (alarmMasterGainNode) {
                  gain1.connect(alarmMasterGainNode);
                } else {
                  gain1.connect(audioContext.destination);
                }
                osc1.onended = () => {
                  const idx = activeAlarmOscillators.indexOf(osc1);
                  if (idx !== -1) activeAlarmOscillators.splice(idx, 1);
                };
                osc1.start(startT);
                osc1.stop(endT);
                activeAlarmOscillators.push(osc1);

                // Gentle harmonic overtone (triangle)
                const osc2 = audioContext.createOscillator();
                const gain2 = audioContext.createGain();
                osc2.type = 'triangle';
                osc2.frequency.setValueAtTime(n.freq * 2, startT);
                gain2.gain.setValueAtTime(n.vol * 0.2, startT);
                gain2.gain.exponentialRampToValueAtTime(0.001, startT + n.dur * 0.6);
                osc2.connect(gain2);
                if (alarmMasterGainNode) {
                  gain2.connect(alarmMasterGainNode);
                } else {
                  gain2.connect(audioContext.destination);
                }
                osc2.onended = () => {
                  const idx = activeAlarmOscillators.indexOf(osc2);
                  if (idx !== -1) activeAlarmOscillators.splice(idx, 1);
                };
                osc2.start(startT);
                osc2.stop(startT + n.dur * 0.6);
                activeAlarmOscillators.push(osc2);
              });
            } catch(_) {
              _playHtml5FallbackChime();
            }
          };

          if (audioContext.state === 'suspended') {
            audioContext.resume().then(() => {
              if (isAlarmRunning) doSynth();
            }).catch(() => {
              if (isAlarmRunning) _playHtml5FallbackChime();
            });
          } else {
            doSynth();
          }
        } else {
          _playHtml5FallbackChime();
        }
      } catch (e) {
        console.warn('Audio play err:', e);
        _playHtml5FallbackChime();
      }

      if (isAlarmRunning) doVibrate();
    }

    function _playHtml5FallbackChime() {
      if (!isAlarmRunning) return;
      try {
        const uri = getFallbackChimeUri();
        if (uri) {
          if (currentAlarmAudio) {
            try { currentAlarmAudio.pause(); currentAlarmAudio.src = ''; } catch(_) {}
          }
          currentAlarmAudio = new Audio(uri);
          currentAlarmAudio.volume = 1.0;
          const p = currentAlarmAudio.play();
          if (p && typeof p.catch === 'function') {
            p.catch(() => {});
          }
        }
      } catch(_) {}
    }

    // Repeating Alarm Chime Loop: plays every 1.8s reliably until user taps Silence
    function runAlarmSequenceLoop() {
      if (!isAlarmRunning || isAlarmPermanentlyDismissed || isOrderAlarmDismissed()) return;

      // Play pure 4-tone crystalline cafe chime
      playAlarmSound();

      if (alarmLoopTimeout) clearTimeout(alarmLoopTimeout);
      alarmLoopTimeout = setTimeout(() => {
        if (!isAlarmRunning || isAlarmPermanentlyDismissed || isOrderAlarmDismissed()) return;
        runAlarmSequenceLoop();
      }, 1800);
    }

    function startRepeatingAlarm() {
      if (isOrderAlarmDismissed()) return;
      if (prevTrackStatus === 'completed' || _store.getItem('orderCompleted') === 'true') {
        return;
      }
      if (isAlarmRunning) return; // Already running

      isAlarmRunning = true;
      isAlarmPermanentlyDismissed = false; // Reset dismiss flag since alarm is explicitly triggered

      document.body.classList.add('alarm-active');
      const numEl = document.getElementById('alarmModalOrderNum');
      const tableEl = document.getElementById('alarmModalTableInfo');
      if (numEl) numEl.innerText = activeTrackedOrderNum || _store.getItem('activeOrderNum') || '#1';
      const isTk = currentOrderType === 'takeaway' || String(currentTable).toLowerCase().includes('take');
      if (tableEl) tableEl.innerText = isTk ? 'Take Out' : `\${currentTable} • Dine-In`;

      const btn = document.getElementById('btnDismissReadyAlarmModal');
      if (btn) {
        btn.disabled = false;
        btn.innerHTML = '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"></polyline></svg><span>Okay, Claim Order</span>';
      }

      const modal = document.getElementById('readyAlarmModal');
      if (modal) modal.style.display = 'flex';

      startVibrationLoop();

      try {
        if ('wakeLock' in navigator) {
          navigator.wakeLock.request('screen').catch(e => {});
        }
      } catch(e) {}

      try {
        if ('Notification' in window && Notification.permission === 'granted') {
          new Notification('ORDER READY ' + (activeTrackedOrderNum || '') + '!', {
            body: 'Your drink is ready! Please come to the pickup counter.',
            icon: '/logo.png',
            vibrate: [600, 200, 600, 200, 1000],
            requireInteraction: true
          });
        }
      } catch(e) {}

      initAudio();

      // Fallback gesture unlock in case browser blocked autoplay
      const _unlockAndChimeOnTap = () => {
        if (!isAlarmRunning || isOrderAlarmDismissed()) return;
        if (audioContext && audioContext.state === 'suspended') {
          audioContext.resume().then(() => {
            if (isAlarmRunning) playAlarmSound();
          }).catch(() => {});
        }
      };
      window.addEventListener('pointerdown', _unlockAndChimeOnTap, { once: true, passive: true });
      window.addEventListener('touchstart', _unlockAndChimeOnTap, { once: true, passive: true });

      // Start the repeating alarm sequence loop
      runAlarmSequenceLoop();
    }

    function speakReadyAnnouncement(onEnd) {
      if (onEnd) onEnd();
    }

    function stopAlarm(e, userDismiss = true) {
      if (e) {
        try { e.preventDefault(); e.stopPropagation(); } catch(_) {}
      }

      // 1. Immediately flag alarm as stopped
      isAlarmRunning = false;

      // 2. Clear any pending timeouts and intervals in the sequence loop
      if (alarmLoopTimeout) {
        clearTimeout(alarmLoopTimeout);
        alarmLoopTimeout = null;
      }
      if (alarmInterval) {
        clearInterval(alarmInterval);
        alarmInterval = null;
      }
      if (fallbackChimeTimeout) {
        clearTimeout(fallbackChimeTimeout);
        fallbackChimeTimeout = null;
      }
      if (ttsVoiceTimeout) {
        clearTimeout(ttsVoiceTimeout);
        ttsVoiceTimeout = null;
      }
      if (ttsWatchdogTimeout) {
        clearTimeout(ttsWatchdogTimeout);
        ttsWatchdogTimeout = null;
      }
      if (ttsKeepAliveInterval) {
        clearInterval(ttsKeepAliveInterval);
        ttsKeepAliveInterval = null;
      }
      window._ttsActiveUtterance = null;

      // 3. Immediately silence Web Audio (zero gain & stop active oscillators)
      try {
        if (audioContext && alarmMasterGainNode) {
          alarmMasterGainNode.gain.cancelScheduledValues(audioContext.currentTime);
          alarmMasterGainNode.gain.setValueAtTime(0, audioContext.currentTime);
        }
      } catch(_) {}

      if (activeAlarmOscillators && activeAlarmOscillators.length > 0) {
        activeAlarmOscillators.forEach(osc => {
          try { osc.stop(); osc.disconnect(); } catch(_) {}
        });
        activeAlarmOscillators = [];
      }

      // 4. Immediately stop HTML5 audio
      if (currentAlarmAudio) {
        try {
          currentAlarmAudio.pause();
          currentAlarmAudio.currentTime = 0;
          currentAlarmAudio.src = '';
        } catch(_) {}
        currentAlarmAudio = null;
      }

      // 5. Immediately stop active voice buffer or utterance
      if (activeSpeechUtterance) {
        try {
          if (typeof activeSpeechUtterance.stop === 'function') {
            activeSpeechUtterance.stop();
          }
          activeSpeechUtterance.onend = null;
          activeSpeechUtterance.onerror = null;
        } catch(_) {}
        activeSpeechUtterance = null;
      }
      try {
        if ('speechSynthesis' in window && window.speechSynthesis.speaking) {
          window.speechSynthesis.onvoiceschanged = null;
          window.speechSynthesis.cancel();
        }
      } catch(e) {}

      // 6. Stop vibration
      stopVibrationLoop();

      // 7. Hide modal and remove active styles
      document.body.classList.remove('alarm-active');
      const modal = document.getElementById('readyAlarmModal');
      if (modal) modal.style.display = 'none';

      // 8. ONLY persist dismissed state if explicitly dismissed by user interaction
      if (userDismiss) {
        isAlarmPermanentlyDismissed = true;
        const orderKey = activeTrackedOrderNum || _store.getItem('activeOrderNum');
        const orderIdKey = activeTrackedOrderId || _store.getItem('activeOrderId');
        if (orderKey || orderIdKey) {
          const cleanNum = orderKey ? String(orderKey).replace('#', '').trim() : '';
          const cleanId = orderIdKey ? String(orderIdKey).replace('#', '').trim() : '';

          if (cleanNum) dismissedOrderNumber = cleanNum;
          if (cleanId) dismissedOrderId = cleanId;

          try {
            if (cleanNum) {
              _store.setItem('alarmDismissed_' + cleanNum, 'true');
              _store.setItem('alarmDismissed_#' + cleanNum, 'true');
            }
            if (cleanId) {
              _store.setItem('alarmDismissed_' + cleanId, 'true');
            }
          } catch(e) {}
        }
      }

      // Update button text for immediate touch feedback
      const btn = document.getElementById('btnDismissReadyAlarmModal');
      if (btn) {
        btn.innerHTML = '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"></polyline></svg><span>Okay, Claim Order</span>';
      }

      if (userDismiss) {
        window._readyOkayClicked = true;
      }

      const orderAnotherBtn = document.getElementById('btnOrderAnotherItem');
      if (orderAnotherBtn) {
        orderAnotherBtn.style.display = 'inline-flex';
        orderAnotherBtn.className = 'btn-order-another';
        orderAnotherBtn.innerHTML = '<svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M3 12a9 9 0 0 1 9-9 9.75 9.75 0 0 1 6.74 2.74L21 8"></path><polyline points="21 3 21 8 16 8"></polyline><path d="M21 12a9 9 0 0 1-9 9 9.75 9.75 0 0 1-6.74-2.74L3 16"></path><polyline points="8 16 3 16 3 21"></polyline></svg><span>Order Again</span>';
      }
    }


    function connectCustomerWs() {
      const loc = window.location;
      const wsUrl = (loc.protocol === 'https:' ? 'wss://' : 'ws://') + loc.host + '/ws';
      try {
        custWs = new WebSocket(wsUrl);
        custWs.onmessage = (e) => {
          try {
            const data = JSON.parse(e.data);
            if (data.type === 'ORDER_STATUS_UPDATE') {
              const cleanId = (activeTrackedOrderId || '').toLowerCase();
              const cleanNum = (activeTrackedOrderNum || '').toLowerCase();
              const msgId = (data.orderId || '').toLowerCase();
              const msgNum = (data.orderNumber || '').toLowerCase();
              const cleanMsgNum = msgNum.replace('#', '').trim();
              const cleanCurrentNum = cleanNum.replace('#', '').trim();

              if (msgId === cleanId || msgNum === cleanNum || (cleanMsgNum && cleanMsgNum === cleanCurrentNum)) {
                if (data.status === 'cancelled') {
                  if (pollInterval) { clearInterval(pollInterval); pollInterval = null; }
                  showSuccessModal({
                    title: 'Order Cancelled',
                    message: 'Your order was cancelled by the cashier. You can now place a new order.',
                    buttonText: 'Return to Menu',
                    onDismiss: () => newOrder(true)
                  });
                  return;
                }
                updateTrackerUI(data.status);
              }
            } else if (data.type === 'SYNC_ORDERS') {
              if (activeTrackedOrderId || activeTrackedOrderNum) {
                const cleanId = (activeTrackedOrderId || '').toLowerCase();
                const cleanNum = (activeTrackedOrderNum || '').toLowerCase();
                const found = (data.orders || []).find(o => {
                  const oid = (o.id || '').toLowerCase();
                  const onum = (o.orderNumber || '').toLowerCase();
                  return oid === cleanId || onum === cleanNum || onum === cleanId;
                });
                if (found && found.status) {
                  updateTrackerUI(found.status);
                } else if (!found && prevTrackStatus && prevTrackStatus !== 'completed' && prevTrackStatus !== 'cancelled') {
                  // Order is no longer in active KDS queue (completed or cancelled by barista) -> check server status
                  checkOrderStatus();
                }
              }
              // Also update live queue from the broadcast order list
              const orders = data.orders || [];
              const formatChip = (o) => {
                if (!o) return '';
                const num = o.orderNumber || '';
                let tbl = (o.tableNumber || '').trim().replace(/^T+able/i, 'Table');
                const isTakeout = o.orderType === 'takeaway' || o.orderType === 'delivery' || tbl.toLowerCase().includes('take');
                const tablePart = isTakeout ? ' · Takeout' : (tbl ? (tbl.toLowerCase().startsWith('table') ? ' · ' + tbl : ' · Table ' + tbl) : '');
                return `\${num}\${tablePart}`;
              };
              const nowPreparing = orders.filter(o => ['preparing','brewing','kitchen'].includes((o.status||'').toLowerCase())).map(formatChip);
              const inQueue = orders.filter(o => ['confirmed','inqueue','queue'].includes((o.status||'').toLowerCase())).map(formatChip);
              const nowReady = orders.filter(o => (o.status||'').toLowerCase() === 'ready').map(formatChip);
              renderLiveQueue(nowPreparing, inQueue, nowReady);
            } else if (data.type === 'SYNC_MENU') {
              if (data.menu && Array.isArray(data.menu)) {
                menuData = data.menu;
                updateCategoryBar();
                renderMenu();
                if (selectedItem) {
                  const updated = menuData.find(m => m.id === selectedItem.id);
                  if (updated) {
                    selectedItem = updated;
                    if (selectedItem.inStock === false) {
                      closeCustomModal();
                      showToast('The item you were viewing has just sold out.');
                    }
                  }
                }
              }
            }
          } catch(err) {}
        };
        custWs.onclose = () => setTimeout(connectCustomerWs, 3000);
      } catch(err) {
        setTimeout(connectCustomerWs, 3000);
      }
    }

    function handleSearch(val) {
      currentSearch = (val || '').trim().toLowerCase();
      document.getElementById('clearSearchBtn').style.display = currentSearch ? 'flex' : 'none';
      renderMenu();
    }

    function clearSearch() {
      document.getElementById('searchInput').value = '';
      currentSearch = '';
      document.getElementById('clearSearchBtn').style.display = 'none';
      renderMenu();
    }

    function filterCategory(cat, btn) {
      activeCategory = cat;
      document.querySelectorAll('.cat-tab').forEach(b => b.classList.remove('active'));
      if (btn) btn.classList.add('active');
      renderMenu();
    }

    function updateCategoryBar() {
      const catBar = document.getElementById('catBar');
      if (!catBar) return;
      const customCats = new Map();
      (menuData || []).forEach(m => {
        if (m.customCategory && m.customCategory.trim()) {
          const name = m.customCategory.trim();
          if (!customCats.has(name)) {
            customCats.set(name, m.categoryLabel || name);
          }
        }
      });
      catBar.querySelectorAll('.custom-cat-tab').forEach(el => el.remove());
      customCats.forEach((label, name) => {
        categoryLabels[name] = label;
        const btn = document.createElement('button');
        btn.className = 'cat-tab custom-cat-tab' + (activeCategory === name ? ' active' : '');
        btn.innerText = label;
        btn.onclick = function() { filterCategory(name, this); };
        catBar.appendChild(btn);
      });
    }

    function escapeHtml(s) {
      if (!s) return '';
      return String(s)
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#39;');
    }

    function renderMenu() {
      if (_tableAuth.hasTableAttempt && !_tableAuth.isVerified) {
        showUnverifiedTableModal(_tableAuth.tableNumber);
        return;
      }
      const grid = document.getElementById('menuGrid');
      let filtered = menuData;

      if (activeCategory !== 'all') {
        filtered = filtered.filter(m => m.category === activeCategory || m.customCategory === activeCategory);
      }

      if (currentSearch) {
        filtered = filtered.filter(m => {
          const name = (m.name || '').toLowerCase();
          const desc = (m.description || '').toLowerCase();
          const cat = (m.categoryLabel || m.category || '').toLowerCase();
          const tags = (m.tags || []).join(' ').toLowerCase();
          return name.includes(currentSearch) || desc.includes(currentSearch) || cat.includes(currentSearch) || tags.includes(currentSearch);
        });
      }

      const label = currentSearch ? `Search Results for "\${currentSearch}"` : (categoryLabels[activeCategory] || 'Menu Items');
      document.getElementById('sectionTitleLabel').innerText = label;
      document.getElementById('menuCountBadge').innerText = `\${filtered.length} item\${filtered.length !== 1 ? 's' : ''}`;

      const heroSpotlightEl = document.getElementById('heroSpotlight');
      if (heroSpotlightEl) {
        heroSpotlightEl.style.display = (activeCategory === 'all' && !currentSearch) ? 'flex' : 'none';
      }

      if (filtered.length === 0) {
        grid.innerHTML = `
          <div class="empty-state">
            <div class="empty-icon">✕</div>
            <h3>No matching items found</h3>
            <p style="font-size: 12px; margin-top: 4px;">Try searching for another coffee or dessert.</p>
          </div>
        `;
        return;
      }

      grid.innerHTML = filtered.map(item => {
        const isSoldOut = item.inStock === false;
        const isKitchen = (item.category === 'streetBites' || item.category === 'pastaDishes' || item.category === 'sandwich' || item.category === 'dinner') ||
          ['wings', 'buffalo', 'fries', 'stick', 'lumpia', 'shanghai', 'pasta', 'carbonara', 'aglio', 'sandwich', 'toast', 'bbq', 'barbeque', 'combo', 'rice', 'inasal', 'sisig'].some(k => (item.name || '').toLowerCase().includes(k));
        const kitchenTag = isKitchen ? '<span style="background: rgba(255,87,34,0.2); border: 1px solid rgba(255,87,34,0.5); color: #FF7043; font-size: 8.5px; font-weight: 800; padding: 1.5px 5px; border-radius: 4px; text-transform: uppercase;">Kitchen</span>' : '';
        const soldOutBadge = isSoldOut ? '<span style="background: rgba(229,57,53,0.25); border: 1px solid #E53935; color: #FF6B6B; font-size: 8.5px; font-weight: 800; padding: 1.5px 5px; border-radius: 4px; text-transform: uppercase;">Sold Out</span>' : '';

        const rawImg = item.imageBase64 ? ('data:image/png;base64,' + item.imageBase64) : (item.imageUrl || (item.imagePath ? (item.imagePath.startsWith('assets/') ? ('/' + item.imagePath) : `/api/item-image?id=\${item.id}`) : ''));
        const imgUrl = rawImg;
        const imageCardHtml = imgUrl ? `
          <div class="item-img-container">
            <img src="\${imgUrl}" alt="\${escapeHtml(item.name)}" onerror="this.parentElement.innerHTML='<div class=\\'item-img-placeholder\\'><span style=\\'font-family:Cinzel;font-weight:bold;font-size:22px;color:#D4AF37;\\'>CELESTIAL</span></div>'">
            \${isSoldOut ? '<div style="position:absolute; inset:0; background:rgba(0,0,0,0.68); display:flex; align-items:center; justify-content:center; border-radius:14px;"><span style="background:#E53935; color:#fff; font-size:10px; font-weight:bold; padding:3px 8px; border-radius:6px; letter-spacing:0.8px;">SOLD OUT</span></div>' : ''}
          </div>
        ` : `
          <div class="item-img-container">
            <div class="item-img-placeholder">
              <span style="font-family:'Cinzel',serif;font-weight:800;font-size:24px;letter-spacing:2px;color:var(--gold-light);">☕</span>
            </div>
            \${isSoldOut ? '<div style="position:absolute; inset:0; background:rgba(0,0,0,0.68); display:flex; align-items:center; justify-content:center; border-radius:14px;"><span style="background:#E53935; color:#fff; font-size:10px; font-weight:bold; padding:3px 8px; border-radius:6px; letter-spacing:0.8px;">SOLD OUT</span></div>' : ''}
          </div>
        `;

        const cardClass = isSoldOut ? 'item-card sold-out' : 'item-card';
        const cardStyle = isSoldOut ? 'opacity: 0.65;' : '';
        const clickAttr = isSoldOut ? "showToast('This item is currently sold out.')" : ("openCustomModal('" + item.id + "')");
        const priceDisplay = isSoldOut 
          ? '<span style="font-size: 13.5px; color: #888;">Unavailable</span>' 
          : '<span class="peso-symbol">₱</span>' + Math.round(item.price);
        const catText = (item.categoryLabel || item.category || 'COFFEE').toUpperCase();
        const descText = item.description || (item.tags && item.tags.length > 0 ? item.tags.join(', ') : '');

        return `
          <div class="\${cardClass}" style="\${cardStyle}" onclick="\${clickAttr}">
            \${imageCardHtml}
            <div class="item-card-info">
              <div class="item-card-name" style="\${isSoldOut ? 'text-decoration: line-through; color: #888;' : ''}">\${escapeHtml(item.name)}</div>
              <div class="item-card-cat">
                <span>\${escapeHtml(catText)}</span>
                \${kitchenTag}
                \${soldOutBadge}
              </div>
              <div class="item-card-desc">\${escapeHtml(descText)}</div>
            </div>
            <div class="item-card-bottom">
              <div class="item-price">\${priceDisplay}</div>
              <button class="btn-add-circle" onclick="event.stopPropagation(); \${clickAttr}" aria-label="Add \${escapeHtml(item.name)} to tray">
                <svg viewBox="0 0 24 24" fill="none" stroke-linecap="round" stroke-linejoin="round">
                  <line x1="12" y1="5" x2="12" y2="19"></line>
                  <line x1="5" y1="12" x2="19" y2="12"></line>
                </svg>
              </button>
            </div>
          </div>
        `;
      }).join('');
    }

    function openSignatureLatteItem() {
      initAudio();
      const item = (menuData || []).find(m => m.id === 'nesp_1' || (m.name && m.name.toLowerCase().includes('celestial signature latte')));
      if (item) {
        // Set search query and render so the item card appears directly in the catalog grid below
        const searchInput = document.getElementById('searchInput');
        if (searchInput) {
          searchInput.value = item.name;
          currentSearch = item.name.toLowerCase();
          const clearBtn = document.getElementById('clearSearchBtn');
          if (clearBtn) clearBtn.style.display = 'block';
        }
        activeCategory = 'all';
        document.querySelectorAll('.cat-tab').forEach(t => t.classList.remove('active'));
        const allTab = document.querySelector('.cat-tab');
        if (allTab) allTab.classList.add('active');
        renderMenu();

        // Also open the rich customization modal for Celestial Signature Latte immediately
        openCustomModal(item.id);
      }
    }

    function openCustomModal(itemId) {
      initAudio();
      selectedItem = menuData.find(m => m.id === itemId);
      if (!selectedItem) return;

      modalItemQty = 1;
      document.getElementById('modalQtyDisplay').innerText = modalItemQty;
      selectedCustomizations = [];

      // Item Media / Showcase Photo
      const imgUrl = selectedItem.imageBase64 ? ('data:image/png;base64,' + selectedItem.imageBase64) : (selectedItem.imageUrl || (selectedItem.imagePath ? (selectedItem.imagePath.startsWith('assets/') ? ('/' + selectedItem.imagePath) : `/api/item-image?id=\${selectedItem.id}`) : ''));
      const thumbImg = document.getElementById('modalThumbImg');
      const thumbIcon = document.getElementById('modalThumbIcon');
      if (imgUrl) {
        thumbImg.src = imgUrl;
        thumbImg.style.display = 'block';
        thumbIcon.style.display = 'none';
      } else {
        thumbImg.style.display = 'none';
        thumbIcon.innerText = selectedItem.icon || '☕';
        thumbIcon.style.display = 'flex';
      }

      document.getElementById('modalItemName').innerText = selectedItem.name;
      document.getElementById('modalBasePriceBadge').innerText = `₱\${Math.round(selectedItem.price)}`;
      const descEl = document.getElementById('modalItemDesc');
      if (descEl) {
        const descText = selectedItem.description || (selectedItem.tags && selectedItem.tags.length > 0 ? selectedItem.tags.join(', ') : '');
        if (descText && descText.trim().length > 0) {
          descEl.innerText = descText.trim();
          descEl.style.display = 'block';
        } else {
          descEl.style.display = 'none';
        }
      }

      function getGroupIconSvg(titleLower) {
        if (titleLower.includes('temp')) {
          return '<svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="#C48248" stroke-width="2.3" stroke-linecap="round" stroke-linejoin="round"><path d="M14 14.76V3.5a2.5 2.5 0 0 0-5 0v11.26a4.5 4.5 0 1 0 5 0z"></path></svg>';
        }
        if (titleLower.includes('sweet') || titleLower.includes('sugar')) {
          return '<svg width="13" height="13" viewBox="0 0 24 24" fill="currentColor" style="color:#C48248;"><path d="M12 2.69l5.66 5.66a8 8 0 1 1-11.31 0z"></path></svg>';
        }
        if (titleLower.includes('add') || titleLower.includes('extra') || titleLower.includes('sinker')) {
          return '<svg width="13" height="13" viewBox="0 0 24 24" fill="currentColor" style="color:#C48248;"><path d="M12 2L14.4 9.6L22 12L14.4 14.4L12 22L9.6 14.4L2 12L9.6 9.6L12 2Z" /></svg>';
        }
        return '<svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="#C48248" stroke-width="2.3" stroke-linecap="round" stroke-linejoin="round"><path d="M18 8h1a4 4 0 0 1 0 8h-1"></path><path d="M2 8h16v9a4 4 0 0 1-4 4H6a4 4 0 0 1-4-4V8z"></path></svg>';
      }

      // Customization Groups
      const container = document.getElementById('customGroupContainer');
      const groups = selectedItem.customizations || [];

      container.innerHTML = groups.map((g, gIdx) => {
        const titleLower = (g.groupTitle || '').toLowerCase();
        const idLower = (g.id || '').toLowerCase();
        const isTemp = titleLower.includes('temp') || idLower.includes('temp');
        const isSweet = titleLower.includes('sweet') || idLower.includes('sweet') || titleLower.includes('sugar');
        const isMulti = g.isMultiSelect === true;
        const isRequired = isTemp || isSweet || g.isRequired === true;

        const iconSvg = getGroupIconSvg(titleLower);
        const groupTitleDisplay = g.groupTitle || 'Options';

        const badgeHtml = isRequired
          ? ''
          : '<div class="cust-group-badge optional">OPTIONAL</div>';

        let optionsHtml = '';

        if (isTemp) {
          // Temperature: Strictly HOT and ICED only
          const validTempOptions = g.options.filter(o => {
            const nameLower = (o.name || '').toLowerCase();
            if (nameLower.includes('&') || nameLower.includes('and')) return false;
            return nameLower.includes('hot') || nameLower.includes('ice');
          });

          // Ensure default selection
          const defaultIdx = (g.defaultIndex >= 0 && g.defaultIndex < validTempOptions.length)
            ? g.defaultIndex
            : (validTempOptions.findIndex(o => o.name.toLowerCase().includes('ice')) >= 0
                ? validTempOptions.findIndex(o => o.name.toLowerCase().includes('ice'))
                : 0);
          const chosenOpt = validTempOptions[defaultIdx] || validTempOptions[0];
          if (chosenOpt) {
            selectedCustomizations.push({
              groupTitle: g.groupTitle,
              optionName: chosenOpt.name,
              extraPrice: chosenOpt.priceAdjustment || 0,
              isMulti: false
            });
          }

          optionsHtml = `
            <div class="cust-pill-row cust-group-options">
              \${validTempOptions.map((opt) => {
                const isSelected = chosenOpt && chosenOpt.name === opt.name;
                const extra = opt.priceAdjustment || 0;
                const extraText = extra > 0 ? `+₱\${Math.round(extra)}` : '';
                return `
                  <button type="button" class="cust-pill-btn \${isSelected ? 'selected' : ''}" onclick="selectPillOption(\${gIdx}, '\${escapeHtml(opt.name)}', \${extra}, this)">
                    <span class="cust-radio-ring"><span class="cust-radio-dot" style="\${isSelected ? 'display:block;' : ''}"></span></span>
                    <span class="cust-pill-label">\${escapeHtml(opt.name)}</span>
                    \${extraText ? `<span class="cust-pill-extra">\${extraText}</span>` : ''}
                  </button>
                `;
              }).join('')}
            </div>
          `;
        } else if (isSweet) {
          // Sweetness Level: 2-column grid
          let defaultIdx = (g.defaultIndex >= 0 && g.defaultIndex < g.options.length)
            ? g.defaultIndex
            : g.options.findIndex(o => (o.name || '').toLowerCase().includes('100') || (o.name || '').toLowerCase().includes('regular'));
          if (defaultIdx < 0) defaultIdx = g.options.length - 1;
          const chosenOpt = g.options[defaultIdx] || g.options[0];
          if (chosenOpt) {
            selectedCustomizations.push({
              groupTitle: g.groupTitle,
              optionName: chosenOpt.name,
              extraPrice: chosenOpt.priceAdjustment || 0,
              isMulti: false
            });
          }

          optionsHtml = `
            <div class="cust-pill-grid cust-group-options">
              \${g.options.map((opt) => {
                const isSelected = chosenOpt && chosenOpt.name === opt.name;
                const extra = opt.priceAdjustment || 0;
                const extraText = extra > 0 ? `+₱\${Math.round(extra)}` : '';
                return `
                  <button type="button" class="cust-pill-btn \${isSelected ? 'selected' : ''}" onclick="selectPillOption(\${gIdx}, '\${escapeHtml(opt.name)}', \${extra}, this)">
                    <span class="cust-radio-ring"><span class="cust-radio-dot" style="\${isSelected ? 'display:block;' : ''}"></span></span>
                    <span class="cust-pill-label">\${escapeHtml(opt.name)}</span>
                    \${extraText ? `<span class="cust-pill-extra">\${extraText}</span>` : ''}
                  </button>
                `;
              }).join('')}
            </div>
          `;
        } else if (isMulti || titleLower.includes('addon') || titleLower.includes('extra') || titleLower.includes('sinker')) {
          // Add-ons & Extras: Full width rows with circle + and price
          optionsHtml = `
            <div class="cust-addon-list">
              \${g.options.map((opt) => {
                const extraPrice = opt.priceAdjustment || 0;
                const priceText = extraPrice > 0 ? `+₱\${Math.round(extraPrice)}` : '';
                return `
                  <div class="cust-addon-row" onclick="toggleAddonRow(\${gIdx}, '\${escapeHtml(opt.name)}', \${extraPrice}, this)">
                    <div class="cust-addon-row-left">
                      <span class="cust-addon-circle">+</span>
                      <span>\${escapeHtml(opt.name)}</span>
                    </div>
                    <div class="cust-addon-row-right">\${priceText}</div>
                  </div>
                `;
              }).join('')}
            </div>
          `;
        } else {
          // Generic single-select options (e.g. Size, Rice Choice)
          const defaultIdx = (g.defaultIndex >= 0 && g.defaultIndex < g.options.length) ? g.defaultIndex : 0;
          const chosenOpt = g.options[defaultIdx] || g.options[0];
          if (chosenOpt) {
            selectedCustomizations.push({
              groupTitle: g.groupTitle,
              optionName: chosenOpt.name,
              extraPrice: chosenOpt.priceAdjustment || 0,
              isMulti: false
            });
          }

          const layoutClass = g.options.length <= 2 ? 'cust-pill-row' : (g.options.length <= 4 ? 'cust-pill-grid' : 'cust-addon-list');

          if (g.options.length <= 4) {
            optionsHtml = `
              <div class="\${layoutClass} cust-group-options">
                \${g.options.map((opt) => {
                  const isSelected = chosenOpt && chosenOpt.name === opt.name;
                  const extra = opt.priceAdjustment || 0;
                  const extraText = extra > 0 ? `+₱\${Math.round(extra)}` : '';
                  return `
                    <button type="button" class="cust-pill-btn \${isSelected ? 'selected' : ''}" onclick="selectPillOption(\${gIdx}, '\${escapeHtml(opt.name)}', \${extra}, this)">
                      <span class="cust-radio-ring"><span class="cust-radio-dot" style="\${isSelected ? 'display:block;' : ''}"></span></span>
                      <span class="cust-pill-label">\${escapeHtml(opt.name)}</span>
                      \${extraText ? `<span class="cust-pill-extra">\${extraText}</span>` : ''}
                    </button>
                  `;
                }).join('')}
              </div>
            `;
          } else {
            optionsHtml = `
              <div class="cust-addon-list">
                \${g.options.map((opt) => {
                  const isSelected = chosenOpt && chosenOpt.name === opt.name;
                  const extraPrice = opt.priceAdjustment || 0;
                  const priceText = extraPrice > 0 ? `+₱\${Math.round(extraPrice)}` : '';
                  return `
                    <div class="cust-addon-row \${isSelected ? 'selected' : ''}" onclick="selectSingleAddonRow(\${gIdx}, '\${escapeHtml(opt.name)}', \${extraPrice}, this)">
                      <div class="cust-addon-row-left">
                        <span class="cust-addon-circle">\${isSelected ? '✓' : '+'}</span>
                        <span>\${escapeHtml(opt.name)}</span>
                      </div>
                      <div class="cust-addon-row-right">\${priceText}</div>
                    </div>
                  `;
                }).join('')}
              </div>
            `;
          }
        }

        return `
          <div class="cust-group-section">
            <div class="cust-group-header">
              <div class="cust-group-header-left">
                <div class="cust-group-icon-box">\${iconSvg}</div>
                <div class="cust-group-title">\${escapeHtml(groupTitleDisplay)}</div>
              </div>
              \${badgeHtml}
            </div>
            \${optionsHtml}
          </div>
        `;
      }).join('');

      updateModalAddButtonPrice();
      document.getElementById('customModal').style.display = 'flex';
    }

    function selectPillOption(gIdx, optName, extraPrice, el) {
      const group = selectedItem.customizations[gIdx];
      const container = el.closest('.cust-group-options');
      if (container) {
        container.querySelectorAll('.cust-pill-btn').forEach(b => {
          b.classList.remove('selected');
          const dot = b.querySelector('.cust-radio-dot');
          if (dot) dot.style.display = 'none';
        });
      }
      el.classList.add('selected');
      const dot = el.querySelector('.cust-radio-dot');
      if (dot) dot.style.display = 'block';

      selectedCustomizations = selectedCustomizations.filter(c => c.groupTitle !== group.groupTitle);
      selectedCustomizations.push({
        groupTitle: group.groupTitle,
        optionName: optName,
        extraPrice: extraPrice || 0,
        isMulti: false
      });
      updateModalAddButtonPrice();
    }
    const selectSegmentOption = selectPillOption;

    function toggleAddonRow(gIdx, optName, extraPrice, el) {
      const group = selectedItem.customizations[gIdx];
      el.classList.toggle('selected');
      const isSel = el.classList.contains('selected');
      const circleEl = el.querySelector('.cust-addon-circle');
      if (isSel) {
        if (circleEl) circleEl.innerText = '✓';
        selectedCustomizations.push({
          groupTitle: group.groupTitle,
          optionName: optName,
          extraPrice: extraPrice || 0,
          isMulti: true
        });
      } else {
        if (circleEl) circleEl.innerText = '+';
        selectedCustomizations = selectedCustomizations.filter(c => !(c.groupTitle === group.groupTitle && c.optionName === optName));
      }
      updateModalAddButtonPrice();
    }

    function selectSingleAddonRow(gIdx, optName, extraPrice, el) {
      const group = selectedItem.customizations[gIdx];
      el.parentElement.querySelectorAll('.cust-addon-row').forEach(b => {
        b.classList.remove('selected');
        const c = b.querySelector('.cust-addon-circle');
        if (c) c.innerText = '+';
      });
      el.classList.add('selected');
      const c = el.querySelector('.cust-addon-circle');
      if (c) c.innerText = '✓';

      selectedCustomizations = selectedCustomizations.filter(c => c.groupTitle !== group.groupTitle);
      selectedCustomizations.push({
        groupTitle: group.groupTitle,
        optionName: optName,
        extraPrice: extraPrice || 0,
        isMulti: false
      });
      updateModalAddButtonPrice();
    }

    function changeModalQty(delta) {
      modalItemQty = Math.max(1, modalItemQty + delta);
      document.getElementById('modalQtyDisplay').innerText = modalItemQty;
      updateModalAddButtonPrice();
    }

    function updateModalAddButtonPrice() {
      const extraTotal = selectedCustomizations.reduce((sum, c) => sum + (c.extraPrice || 0), 0);
      const unitTotal = selectedItem.price + extraTotal;
      const grandTotal = unitTotal * modalItemQty;
      const btnText = document.getElementById('modalAddBtnText');
      if (btnText) {
        btnText.innerText = `Add to Order • ₱\${Math.round(grandTotal)}`;
      }
    }

    function confirmAddToCart() {
      const btn = document.getElementById('btnAddItemToCart');
      const btnText = document.getElementById('modalAddBtnText');
      if (btn) {
        if (btnText) btnText.innerText = 'Adding to Order...';
        btn.disabled = true;
      }
      setTimeout(() => {
        const notes = '';
        const extraTotal = selectedCustomizations.reduce((sum, c) => sum + (c.extraPrice || 0), 0);
        const itemImg = selectedItem.imageBase64
          ? ('data:image/png;base64,' + selectedItem.imageBase64)
          : (selectedItem.imageUrl || (selectedItem.imagePath ? (selectedItem.imagePath.startsWith('assets/') ? ('/' + selectedItem.imagePath) : `/api/item-image?id=\${selectedItem.id}`) : ''));

        cart.push({
          id: selectedItem.id,
          name: selectedItem.name,
          price: selectedItem.price,
          extraPrice: extraTotal,
          unitPrice: selectedItem.price + extraTotal,
          quantity: modalItemQty,
          customizations: [...selectedCustomizations],
          notes: notes,
          category: selectedItem.category,
          imageUrl: itemImg,
          icon: selectedItem.icon
        });

        if (btn) btn.disabled = false;
        closeModal('customModal');
        updateCartBar();
      }, 160);
    }

    function updateCartBar() {
      const count = cart.reduce((sum, i) => sum + i.quantity, 0);
      const total = cart.reduce((sum, i) => sum + (i.unitPrice * i.quantity), 0);

      if (count > 0) {
        document.getElementById('cartBar').style.display = 'flex';
        document.getElementById('cartCountText').innerText = `\${count} item\${count > 1 ? 's' : ''}`;
        document.getElementById('cartTotalText').innerText = `₱\${Math.round(total)}`;
        // Persist cart so it survives an accidental page refresh
        try { _store.setItem('pendingCart', JSON.stringify(cart)); } catch(_) {}
      } else {
        document.getElementById('cartBar').style.display = 'none';
        try { _store.removeItem('pendingCart'); } catch(_) {}
      }
    }

    function openTrayModal() {
      const btn = document.getElementById('btnSendOrder');
      if (btn) {
        btn.innerText = 'Submit Order to Cashier';
        btn.disabled = false;
      }

      const list = document.getElementById('trayItemsList');
      const total = cart.reduce((sum, i) => sum + (i.unitPrice * i.quantity), 0);

      list.innerHTML = cart.map((item, idx) => {
        const mItem = (typeof menuData !== 'undefined' && Array.isArray(menuData))
          ? menuData.find(m => m.id === item.id || (m.name && item.name && m.name.toLowerCase() === item.name.toLowerCase()))
          : null;

        const rawImg = item.imageUrl ||
          (item.imageBase64 ? ('data:image/png;base64,' + item.imageBase64) : null) ||
          (mItem ? (mItem.imageBase64 ? ('data:image/png;base64,' + mItem.imageBase64) : (mItem.imageUrl || (mItem.imagePath ? (mItem.imagePath.startsWith('assets/') ? ('/' + mItem.imagePath) : `/api/item-image?id=\${mItem.id}`) : ''))) : '');
        const itemIcon = item.icon || (mItem && mItem.icon) || '☕';

        const customsBadges = (item.customizations || []).map(c => {
          const priceTxt = (c.extraPrice && c.extraPrice > 0) ? ` (+₱\${Math.round(c.extraPrice)})` : '';
          return `<span style="display: inline-block; background: rgba(212,175,55,0.14); border: 1px solid rgba(212,175,55,0.3); color: var(--gold-light); font-size: 11px; font-weight: 600; padding: 2px 8px; border-radius: 6px; margin-right: 4px; margin-top: 3px;">\${c.optionName}\${priceTxt}</span>`;
        }).join('');
        const isKitchen = (item.category === 'streetBites' || item.category === 'pastaDishes' || item.category === 'sandwich' || item.category === 'dinner') ||
          ['wings', 'buffalo', 'fries', 'stick', 'lumpia', 'shanghai', 'pasta', 'carbonara', 'aglio', 'sandwich', 'toast', 'bbq', 'barbeque', 'combo', 'rice', 'inasal', 'sisig'].some(k => (item.name || '').toLowerCase().includes(k));
        const kitchenBadge = isKitchen ? '<span style="background:rgba(255,87,34,0.2);border:1px solid rgba(255,87,34,0.55);color:#FF7043;font-size:10px;font-weight:800;padding:1px 5px;border-radius:4px;margin-left:5px;">KITCHEN</span>' : '';

        const imgBoxHtml = rawImg ? `
          <div style="width: 58px; height: 58px; border-radius: 12px; overflow: hidden; flex-shrink: 0; background: #181310; border: 1px solid rgba(255,255,255,0.08); display: flex; align-items: center; justify-content: center; position: relative;">
            <img src="\${rawImg}" alt="\${escapeHtml(item.name)}" style="width: 100%; height: 100%; object-fit: cover; display: block;" onerror="this.style.display='none'; this.nextElementSibling.style.display='flex';">
            <div style="display: none; width: 100%; height: 100%; align-items: center; justify-content: center; background: radial-gradient(circle at center, #2C1F16 0%, #181310 100%); font-size: 22px; color: var(--gold-light);">\${itemIcon}</div>
          </div>
        ` : `
          <div style="width: 58px; height: 58px; border-radius: 12px; overflow: hidden; flex-shrink: 0; background: radial-gradient(circle at center, #2C1F16 0%, #181310 100%); border: 1px solid rgba(255,255,255,0.08); display: flex; align-items: center; justify-content: center; font-size: 22px; color: var(--gold-light);">
            \${itemIcon}
          </div>
        `;

        return `
          <div style="background: var(--bg-card); border-radius: var(--radius-md); border: 1px solid var(--border-subtle); padding: 10px 12px; margin-bottom: 10px; display: flex; align-items: center; gap: 12px;">
            \${imgBoxHtml}
            <div style="flex: 1; min-width: 0; padding-right: 2px;">
              <div style="font-weight: 700; font-size: 14px; color: var(--text-light); display: flex; align-items: center; flex-wrap: wrap;">\${item.name}\${kitchenBadge}</div>
              \${customsBadges ? `<div style="margin-top: 4px; display: flex; flex-wrap: wrap; gap: 4px;">\${customsBadges}</div>` : ''}
              \${item.notes ? `<div style="font-size: 11px; color: var(--rose); margin-top: 4px;">Note: "\${item.notes}"</div>` : ''}
              <div style="font-weight: 800; font-size: 14.5px; color: #FFFFFF; margin-top: 5px;">₱\${Math.round(item.unitPrice * item.quantity)}</div>
            </div>
            <div style="display: flex; align-items: center; gap: 6px; flex-shrink: 0;">
              <div style="display: flex; align-items: center; background: rgba(255,255,255,0.06); border-radius: 8px; border: 1px solid rgba(255,255,255,0.1);">
                <button onclick="changeTrayItemQty(\${idx}, -1)" style="background: none; border: none; color: var(--text-light); width: 28px; height: 28px; font-weight: bold; cursor: pointer; display: flex; align-items: center; justify-content: center;">−</button>
                <span style="font-size: 13px; font-weight: 800; color: var(--gold-light); min-width: 18px; text-align: center;">\${item.quantity}</span>
                <button onclick="changeTrayItemQty(\${idx}, 1)" style="background: none; border: none; color: var(--text-light); width: 28px; height: 28px; font-weight: bold; cursor: pointer; display: flex; align-items: center; justify-content: center;">+</button>
              </div>
              <button onclick="removeFromCart(\${idx})" style="background: rgba(231,29,54,0.15); border: 1px solid rgba(231,29,54,0.4); color: var(--rose); border-radius: 8px; width: 28px; height: 28px; font-weight: bold; cursor: pointer; display: flex; align-items: center; justify-content: center;">✕</button>
            </div>
          </div>
        `;
      }).join('');

      document.getElementById('trayTotalAmount').innerText = `₱\${Math.round(total)}`;
      document.getElementById('trayModal').style.display = 'flex';
    }

    function changeTrayItemQty(idx, delta) {
      if (cart[idx]) {
        cart[idx].quantity += delta;
        if (cart[idx].quantity <= 0) {
          cart.splice(idx, 1);
        }
        updateCartBar();
        if (cart.length === 0) {
          closeModal('trayModal');
        } else {
          openTrayModal();
        }
      }
    }

    function removeFromCart(idx) {
      cart.splice(idx, 1);
      updateCartBar();
      if (cart.length === 0) {
        closeModal('trayModal');
      } else {
        openTrayModal();
      }
    }

    function selectPayment(method, el) {
      selectedPayment = method;
      el.parentElement.querySelectorAll('.opt-chip').forEach(c => c.classList.remove('selected'));
      el.classList.add('selected');
    }

    let confirmModalCallback = null;
    function showConfirmModal(opts) {
      const options = opts || {};
      const modal = document.getElementById('confirmModal');
      const titleEl = document.getElementById('confirmModalTitle');
      const msgEl = document.getElementById('confirmModalMsg');
      const cancelBtn = document.getElementById('btnConfirmCancel');
      const actionBtn = document.getElementById('btnConfirmAction');

      if (titleEl) titleEl.innerText = options.title || 'Please Confirm';
      if (msgEl) msgEl.innerText = options.message || 'Are you sure you want to proceed?';
      if (cancelBtn) cancelBtn.innerText = options.cancelText || 'Cancel';
      if (actionBtn) {
        actionBtn.innerText = options.confirmText || 'Confirm';
        if (options.isDestructive) {
          actionBtn.style.background = 'linear-gradient(135deg, var(--rose) 0%, #B82535 100%)';
          actionBtn.style.color = '#FFFFFF';
        } else {
          actionBtn.style.background = 'linear-gradient(135deg, var(--gold-primary) 0%, #B89025 100%)';
          actionBtn.style.color = '#0D0A0F';
        }
      }

      confirmModalCallback = options.onConfirm;
      if (actionBtn) {
        actionBtn.onclick = function() {
          closeModal('confirmModal');
          if (typeof confirmModalCallback === 'function') {
            confirmModalCallback();
          }
        };
      }

      if (modal) modal.style.display = 'flex';
    }

    let successModalCallback = null;
    function showSuccessModal(opts) {
      const options = opts || {};
      const modal = document.getElementById('successModal');
      const titleEl = document.getElementById('successModalTitle');
      const msgEl = document.getElementById('successModalMsg');
      const btn = document.getElementById('btnSuccessDismiss');

      if (titleEl) titleEl.innerText = options.title || 'Success!';
      if (msgEl) msgEl.innerText = options.message || 'Action completed successfully.';
      if (btn) btn.innerText = options.buttonText || 'Continue';

      successModalCallback = options.onDismiss;
      if (btn) {
        btn.onclick = function() {
          closeSuccessModal();
        };
      }

      if (modal) modal.style.display = 'flex';
    }

    function closeSuccessModal() {
      closeModal('successModal');
      if (typeof successModalCallback === 'function') {
        const cb = successModalCallback;
        successModalCallback = null;
        try { cb(); } catch(e) {}
      }
    }

    function closeModal(modalId) {
      const el = document.getElementById(modalId);
      if (el) el.style.display = 'none';
    }

    function showCustomerVolumeModal(force = false) {
      if (isCustVolumeModalOpen || isCustVolumeDismissing) return;

      const numKey = activeTrackedOrderNum || _store.getItem('activeOrderNum');
      const idKey = activeTrackedOrderId || _store.getItem('activeOrderId');
      const cleanNum = numKey ? String(numKey).replace('#','').trim() : '';
      const cleanId = idKey ? String(idKey).replace('#','').trim() : '';

      if (!force) {
        try {
          if (cleanId && (
            sessionStorage.getItem('custVolumeSeen_' + cleanId) === 'true' ||
            sessionStorage.getItem('custPaymentVolumeSeen_' + cleanId) === 'true'
          )) {
            return;
          }
          if (cleanNum && (
            sessionStorage.getItem('custVolumeSeen_' + cleanNum) === 'true' ||
            sessionStorage.getItem('custPaymentVolumeSeen_' + cleanNum) === 'true'
          )) {
            return;
          }
        } catch(_) {}
      }

      // Prompt volume pop-up ONLY when cashier settles / confirms the order (never when pending!)
      const currentTrackStatus = (prevTrackStatus || _store.getItem('activeOrderStatus') || '').toLowerCase();
      const isSettled = ['confirmed', 'inqueue', 'queue', 'preparing', 'brewing', 'kitchen'].includes(currentTrackStatus);
      if (!isSettled && !force) {
        return;
      }

      const modal = document.getElementById('customerVolumeModal');
      if (!modal) return;
      modal.style.display = 'flex';
      isCustVolumeModalOpen = true;
      isCustVolumeDismissing = false;

      // Update subtitle, title and description text based on order / payment status
      const subtitleEl = document.getElementById('custVolumeModalSubtitle');
      const titleEl = document.getElementById('custVolumeModalTitle');
      const descEl = document.getElementById('custVolumeModalDesc');

      if (subtitleEl) {
        subtitleEl.innerText = isSettled ? 'PAYMENT CONFIRMED • LIVE CHIME READY' : 'LIVE ORDER ACTIVE • AUDIO READY';
      }
      if (titleEl) {
        titleEl.innerText = isSettled ? 'Payment Confirmed! Turn Up Volume' : 'Please Turn Up Your Phone Volume';
        titleEl.style.color = '#FFFFFF';
      }
      if (descEl) {
        if (isSettled) {
          descEl.innerHTML = 'Payment confirmed & settled! Please ensure your phone volume is turned <b>UP</b> so you will hear the live chime alert and announcement when your order is ready for pickup!';
        } else {
          descEl.innerHTML = 'Your order is active! Please ensure your phone volume is turned <b>UP</b> so you will hear the live chime alert and announcement when your order is ready for pickup!';
        }
      }

      // Reset icon and title to default state if previously dismissed
      const iconBox = document.getElementById('custVolumeIconBox');
      if (iconBox) {
        iconBox.style.background = 'rgba(255,255,255,0.06)';
        iconBox.style.borderColor = 'var(--caramel-accent)';
        iconBox.style.color = 'var(--caramel-accent)';
        iconBox.style.boxShadow = 'none';
        iconBox.innerHTML = '<svg width="38" height="38" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><polygon points="11 5 6 9 2 9 2 15 6 15 11 19 11 5"></polygon><path d="M19.07 4.93a10 10 0 0 1 0 14.14M15.54 8.46a5 5 0 0 1 0 7.07"></path></svg>';
      }

      const confirmBtn = document.getElementById('btnCustVolumeConfirm');
      if (confirmBtn) {
        confirmBtn.disabled = false;
        confirmBtn.style.opacity = '1';
        confirmBtn.style.background = 'var(--caramel-accent)';
        confirmBtn.style.color = '#110E0C';
        confirmBtn.innerHTML = '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polygon points="11 5 6 9 2 9 2 15 6 15 11 19 11 5"></polygon><path d="M19.07 4.93a10 10 0 0 1 0 14.14M15.54 8.46a5 5 0 0 1 0 7.07"></path></svg><span>Test Sound & Confirm Volume</span>';
      }

      // Pre-initialize / unlock Web Audio API and pre-load voice audio
      initAudio();
      loadVoiceAudio();
    }

    function handleCustVolumeAction(actionType) {
      if (!isCustVolumeModalOpen || isCustVolumeDismissing) return;

      const confirmBtn = document.getElementById('btnCustVolumeConfirm');
      const numKey = activeTrackedOrderNum || _store.getItem('activeOrderNum');
      const idKey = activeTrackedOrderId || _store.getItem('activeOrderId');
      const cleanNum = numKey ? String(numKey).replace('#','').trim() : '';
      const cleanId = idKey ? String(idKey).replace('#','').trim() : '';

      try {
        if (cleanNum) {
          sessionStorage.setItem('custVolumeSeen_' + cleanNum, 'true');
          sessionStorage.setItem('custPaymentVolumeSeen_' + cleanNum, 'true');
        }
        if (cleanId) {
          sessionStorage.setItem('custVolumeSeen_' + cleanId, 'true');
          sessionStorage.setItem('custPaymentVolumeSeen_' + cleanId, 'true');
        }
      } catch(_) {}

      if (actionType === 'close') {
        isCustVolumeDismissing = true;
        const modal = document.getElementById('customerVolumeModal');
        if (modal) modal.style.display = 'none';
        isCustVolumeModalOpen = false;
        isCustVolumeDismissing = false;
        return;
      }

      isCustVolumeDismissing = true;
      if (confirmBtn) {
        confirmBtn.disabled = true;
        confirmBtn.style.opacity = '0.95';
        confirmBtn.innerHTML = '<span class="btn-spinner" style="border-top-color: #110E0C; border-left-color: #110E0C;"></span><span>Testing Sound...</span>';
      }

      // 1. Direct synchronous iOS WebKit audio unlock via zero-buffer
      try {
        if (!audioContext) {
          const AC = window.AudioContext || window.webkitAudioContext;
          if (AC) audioContext = new AC();
        }
        if (audioContext) {
          const silentBuf = audioContext.createBuffer(1, 1, 22050);
          const src = audioContext.createBufferSource();
          src.buffer = silentBuf;
          src.connect(audioContext.destination);
          src.start(0);
        }
      } catch(_) {}

      _primeSpeechSynthesis();

      // 2. Play crystalline 3-tone chime for sound & volume verification
      const playChimeTone = () => {
        if (!audioContext) return;
        try {
          const now = audioContext.currentTime;
          const notes = [
            { freq: 1046.50, time: 0.00, dur: 0.28, vol: 0.40 },
            { freq: 1318.51, time: 0.12, dur: 0.30, vol: 0.45 },
            { freq: 1567.98, time: 0.24, dur: 0.42, vol: 0.50 }
          ];
          notes.forEach(n => {
            const osc = audioContext.createOscillator();
            const gain = audioContext.createGain();
            osc.type = 'sine';
            osc.frequency.setValueAtTime(n.freq, now + n.time);
            gain.gain.setValueAtTime(n.vol, now + n.time);
            gain.gain.exponentialRampToValueAtTime(0.001, now + n.time + n.dur);
            osc.connect(gain);
            gain.connect(audioContext.destination);
            osc.start(now + n.time);
            osc.stop(now + n.time + n.dur + 0.05);
          });
        } catch(_) {}
      };

      const completeUnlockAndChime = () => {
        audioUnlocked = true;
        _startAudioKeepAlive();
        playChimeTone();

        // Visual success acknowledgment
        const iconBox = document.getElementById('custVolumeIconBox');
        const titleEl = document.getElementById('custVolumeModalTitle');
        if (iconBox) {
          iconBox.style.background = 'rgba(40,140,120,0.18)';
          iconBox.style.borderColor = '#288C78';
          iconBox.style.color = '#6FE0AC';
          iconBox.innerHTML = '<svg width="38" height="38" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"></polyline></svg>';
        }
        if (titleEl) {
          titleEl.innerText = 'Sound Tested & Volume Confirmed ✓';
          titleEl.style.color = '#6FE0AC';
        }
        if (confirmBtn) {
          confirmBtn.style.background = '#16A34A';
          confirmBtn.style.color = '#FFFFFF';
          confirmBtn.innerHTML = '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"></polyline></svg><span>Volume Ready & Chime Confirmed ✓</span>';
        }

        setTimeout(() => {
          const modal = document.getElementById('customerVolumeModal');
          if (modal) modal.style.display = 'none';
          isCustVolumeModalOpen = false;
          isCustVolumeDismissing = false;
        }, 900);
      };

      if (audioContext) {
        if (audioContext.state === 'running') {
          completeUnlockAndChime();
        } else {
          audioContext.resume().then(() => {
            completeUnlockAndChime();
          }).catch(() => {
            completeUnlockAndChime();
          });
        }
      } else {
        completeUnlockAndChime();
      }
    }

    // Hardware volume keys dismiss & acknowledge volume when modal is visible
    window.addEventListener('keydown', (e) => {
      if (!isCustVolumeModalOpen || isCustVolumeDismissing) return;
      const k = e.key || '';
      const code = e.code || '';
      const isVolKey = k === 'AudioVolumeUp' || code === 'AudioVolumeUp' ||
                       k === 'AudioVolumeDown' || code === 'AudioVolumeDown' ||
                       k === 'VolumeUp' || k === 'VolumeDown' ||
                       k === 'ArrowUp' || k === 'ArrowDown' || k === '+' || k === '=';
      if (isVolKey) {
        handleCustVolumeAction('hardware');
      }
    }, { passive: true });

    async function submitOrderToKitchen() {
      if (!cart || cart.length === 0) {
        showSuccessModal({
          title: 'Your Tray is Empty',
          message: 'Please choose some delicious items and add them to your tray first.',
          buttonText: 'Browse Menu'
        });
        return;
      }

      // Block submission only if user is actively on tracker view
      const trackerEl = document.getElementById('trackerView');
      if (trackerEl && trackerEl.style.display === 'block' && activeTrackedOrderId && prevTrackStatus !== 'completed' && prevTrackStatus !== 'cancelled') {
        showSuccessModal({
          title: 'Active Order In Progress',
          message: 'You already have an active order (' + (activeTrackedOrderNum || '') + '). You cannot order again until your current order is completed or cancelled.',
          buttonText: 'View My Order',
          onDismiss: () => {
            closeModal('trayModal');
            document.getElementById('controlsWrapper').style.display = 'none';
            document.getElementById('menuView').style.display = 'none';
            document.getElementById('cartBar').style.display = 'none';
            document.getElementById('trackerView').style.display = 'block';
            window.scrollTo({ top: 0, behavior: 'smooth' });
          }
        });
        return;
      }
      initAudio();

      const btn = document.getElementById('btnSendOrder');
      if (btn) {
        btn.innerHTML = '<span class="btn-spinner"></span><span>Submitting to Cashier...</span>';
        btn.disabled = true;
      }

      try {
        if ('Notification' in window && Notification.permission === 'default') {
          Notification.requestPermission();
        }
        if ('wakeLock' in navigator) {
          navigator.wakeLock.request('screen').catch(e => {});
        }
      } catch(e) {}

      let submitTimeout = null;
      try {
        if (currentOrderType === 'dineIn') {
          if (!isTableVerified || !currentTable || !currentTableToken) {
            closeModal('trayModal');
            showUnverifiedTableModal(unverifiedTableAttempt || 'the table');
            if (btn) {
              btn.innerHTML = 'Submit Order to Cashier';
              btn.disabled = false;
            }
            return;
          }
        }

        const custNameEl = document.getElementById('custNameInput');
        const defaultGuest = currentOrderType === 'takeaway' ? 'Guest (Takeout)' : `Guest (\${currentTable})`;
        const custName = (custNameEl && custNameEl.value.trim()) ? custNameEl.value.trim() : defaultGuest;

        const payload = {
          orderType: currentOrderType,
          tableNumber: currentOrderType === 'takeaway' ? 'Takeout' : currentTable,
          tableToken: currentTableToken || '',
          customerName: custName,
          paymentMethod: selectedPayment || 'cash',
          items: cart.map(i => ({
            id: i.id,
            quantity: i.quantity || 1,
            notes: i.notes || '',
            customizations: (i.customizations || []).map(c => ({
              groupTitle: c.groupTitle || '',
              optionName: c.optionName || '',
              extraPrice: c.extraPrice || 0
            }))
          }))
        };

        const controller = new AbortController();
        submitTimeout = setTimeout(() => controller.abort(), 15000);

        let res = null;
        try {
          res = await fetch('/api/customer/order', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(payload),
            signal: controller.signal
          });
        } catch (fetchErr) {
          if (submitTimeout) clearTimeout(submitTimeout);
          closeModal('trayModal');
          showSuccessModal({
            title: 'Connection Notice',
            message: 'Could not connect to Cafe server or request timed out. Please ensure you are connected to the Cafe hotspot and try again.',
            buttonText: 'OK'
          });
          return;
        }
        if (submitTimeout) clearTimeout(submitTimeout);

        let data = null;
        try {
          data = await res.json();
        } catch (_) {}

        if (data && data.success && data.orderId) {
          const submittedItems = cart.slice();
          cart = [];
          try {
            _store.removeItem('pendingCart');
            const newCleanNum = String(data.orderNumber || '').replace('#', '').trim();
            const newCleanId = String(data.orderId || '').replace('#', '').trim();
            if (newCleanNum) {
              _store.removeItem('custPaymentVolumeSeen_' + newCleanNum);
              _store.removeItem('custPaymentVolumeSeen_#' + newCleanNum);
              sessionStorage.removeItem('custPaymentVolumeSeen_' + newCleanNum);
              sessionStorage.removeItem('custPaymentVolumeSeen_#' + newCleanNum);
              _store.removeItem('custVolumeSeen_' + newCleanNum);
              _store.removeItem('custVolumeSeen_#' + newCleanNum);
              sessionStorage.removeItem('custVolumeSeen_' + newCleanNum);
              sessionStorage.removeItem('custVolumeSeen_#' + newCleanNum);
            }
            if (newCleanId) {
              _store.removeItem('custPaymentVolumeSeen_' + newCleanId);
              sessionStorage.removeItem('custPaymentVolumeSeen_' + newCleanId);
              _store.removeItem('custVolumeSeen_' + newCleanId);
              sessionStorage.removeItem('custVolumeSeen_' + newCleanId);
            }
            _store.removeItem('custPaymentVolumeSeen_current');
            sessionStorage.removeItem('custPaymentVolumeSeen_current');
            _store.removeItem('custVolumeSeen_current');
            sessionStorage.removeItem('custVolumeSeen_current');
          } catch(_) {}
          updateCartBar();
          closeModal('trayModal');
          initAudio();
          try {
            startOrderTracking(data.orderId, data.orderNumber, data.totalAmount, (data.items && data.items.length > 0) ? data.items : submittedItems);
          } catch(trackErr) {
            console.error('Tracking UI render notice:', trackErr);
          }
        } else if (data && data.requiresQrScan) {
          closeModal('trayModal');
          showUnverifiedTableModal(currentTable || 'the table');
        } else {
          closeModal('trayModal');
          if (data && data.existingOrderId) {
            showSuccessModal({
              title: 'Order In Preparation',
              message: data.error || 'This table already has an order in preparation.',
              buttonText: 'View Active Order',
              onDismiss: () => {
                startOrderTracking(data.existingOrderId, data.existingOrderNumber || '#1', 0, [], data.status || 'pending');
              }
            });
            return;
          }
          showSuccessModal({
            title: 'Order Notice',
            message: (data && data.error) ? data.error : 'Could not submit order. Please try again.',
            buttonText: 'OK'
          });
        }
      } catch (err) {
        if (submitTimeout) clearTimeout(submitTimeout);
        closeModal('trayModal');
        showSuccessModal({
          title: 'Order Notice',
          message: 'An unexpected issue occurred while preparing your order. Please try again.',
          buttonText: 'OK'
        });
      } finally {
        if (btn) {
          btn.innerHTML = 'Submit Order to Cashier';
          btn.disabled = false;
        }
      }
    }

    let activeTrackedItems = [];

    function openOrderDetailsModal() {
      const modal = document.getElementById('orderDetailsModal');
      if (!modal) return;

      const orderNumEl = document.getElementById('detailsModalOrderNum');
      const tableTypeEl = document.getElementById('detailsModalTableType');
      const statusBadgeEl = document.getElementById('detailsModalStatusBadge');
      const statusBannerEl = document.getElementById('detailsModalStatusBanner');
      const dateTimeEl = document.getElementById('detailsModalDateTime');
      const custEl = document.getElementById('detailsModalCustomer');
      const payEl = document.getElementById('detailsModalPayment');
      const countEl = document.getElementById('detailsModalItemCount');
      const subtotalEl = document.getElementById('detailsModalSubtotal');
      const grandTotalEl = document.getElementById('detailsModalGrandTotal');
      const itemsListEl = document.getElementById('detailsModalItemsList');

      const orderNum = activeTrackedOrderNum || _store.getItem('activeOrderNum') || '#1';
      if (orderNumEl) orderNumEl.innerText = orderNum;

      const currentT = currentTable || _store.getItem('activeTableNumber') || '1';
      const isTk = (currentOrderType === 'takeaway' || currentOrderType === 'takeout' || (currentT && String(currentT).toLowerCase().includes('take')));
      if (tableTypeEl) tableTypeEl.innerText = isTk ? 'Take Out' : `Table \${currentT} • Dine-In`;

      const curStatus = prevTrackStatus || 'pending';
      let statusLabel = 'Awaiting Cashier';
      let statusColor = 'var(--gold-primary)';
      let statusBg = 'rgba(212, 163, 89, 0.12)';
      let statusBorder = 'rgba(212, 163, 89, 0.35)';

      if (curStatus === 'preparing' || curStatus === 'brewing') {
        statusLabel = '🔥 Brewing & Kitchen Prep';
        statusColor = 'var(--amber-brewing)';
        statusBg = 'rgba(255, 159, 28, 0.15)';
        statusBorder = 'rgba(255, 159, 28, 0.4)';
      } else if (curStatus === 'ready') {
        statusLabel = '✨ Ready for Pickup';
        statusColor = 'var(--emerald-ready)';
        statusBg = 'rgba(46, 196, 182, 0.15)';
        statusBorder = 'rgba(46, 196, 182, 0.4)';
      } else if (curStatus === 'completed') {
        statusLabel = '✓ Order Completed';
        statusColor = 'var(--emerald-ready)';
        statusBg = 'rgba(46, 196, 182, 0.15)';
        statusBorder = 'rgba(46, 196, 182, 0.4)';
      } else if (curStatus === 'cancelled') {
        statusLabel = '✕ Order Cancelled';
        statusColor = 'var(--rose-alert)';
        statusBg = 'rgba(231, 29, 54, 0.15)';
        statusBorder = 'rgba(231, 29, 54, 0.4)';
      }

      if (statusBadgeEl) {
        statusBadgeEl.innerText = statusLabel;
        statusBadgeEl.style.color = statusColor;
      }
      if (statusBannerEl) {
        statusBannerEl.style.background = statusBg;
        statusBannerEl.style.borderColor = statusBorder;
      }

      const d = new Date();
      if (dateTimeEl) {
        dateTimeEl.innerText = d.toLocaleDateString('en-US', { month: 'short', day: 'numeric' }) + ' • ' + d.toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit', hour12: true });
      }
      if (custEl) custEl.innerText = (typeof currentGuestName !== 'undefined' && currentGuestName) ? currentGuestName : 'Guest Patron';
      if (payEl) payEl.innerText = (typeof currentPaymentMethod !== 'undefined' && currentPaymentMethod) ? currentPaymentMethod.toUpperCase() : 'CASH';

      let items = (activeTrackedItems && activeTrackedItems.length > 0) ? activeTrackedItems : [];
      if (items.length === 0) {
        try {
          items = JSON.parse(_store.getItem('activeOrderItems') || '[]');
        } catch(_) { items = []; }
      }

      const totalQty = items.reduce((sum, i) => sum + (i.quantity || 1), 0);
      if (countEl) countEl.innerText = totalQty;

      const totalVal = parseFloat(_store.getItem('activeOrderTotal') || 0);
      if (subtotalEl) subtotalEl.innerText = `₱\${Math.round(totalVal)}`;
      if (grandTotalEl) grandTotalEl.innerText = `₱\${Math.round(totalVal)}`;

      if (itemsListEl) {
        if (items.length === 0) {
          itemsListEl.innerHTML = '<div style="font-size:12.5px;color:var(--text-muted);text-align:center;padding:16px;">Order details registered with Cashier.</div>';
        } else {
          itemsListEl.innerHTML = items.map(i => {
            const itemName = i.name || i.menuItem?.name || 'Item';
            const isKitchen = i.isKitchen === true ||
              ['streetBites', 'pastaDishes', 'sandwich', 'dinner'].includes((i.category || '').toLowerCase()) ||
              ['wings', 'buffalo', 'fries', 'stick', 'lumpia', 'shanghai', 'pasta', 'carbonara', 'aglio', 'sandwich', 'toast', 'bbq', 'barbeque', 'combo', 'rice', 'inasal', 'sisig'].some(k => itemName.toLowerCase().includes(k));
            const kitchenBadge = isKitchen ? '<span style="background:rgba(255,87,34,0.22);border:1px solid rgba(255,87,34,0.55);color:#FF7043;font-size:10px;font-weight:900;padding:2px 6px;border-radius:4px;margin-left:6px;">KITCHEN</span>' : '';

            const customsList = i.customizations || [];
            const customsText = customsList.map(c => typeof c === 'string' ? c : (c.optionName || c.name || '')).filter(Boolean).join(', ');
            const notesText = i.notes ? `<div style="font-size:11px;color:var(--rose);margin-top:3px;font-weight:600;">Note: "\${i.notes}"</div>` : '';
            const customsHtml = customsText ? `<div style="font-size:11.5px;color:var(--text-muted);margin-top:2px;">› \${customsText}</div>` : '';
            const itemPrice = i.price || i.totalPrice || ((i.unitPrice || 0) * (i.quantity || 1));
            return `
              <div style="display:flex;justify-content:space-between;align-items:flex-start;padding:10px 0;border-bottom:1px solid rgba(255,255,255,0.06);">
                <div style="flex:1;padding-right:12px;">
                  <div style="display:flex;align-items:center;gap:6px;">
                    <span style="font-weight:800;color:var(--caramel-accent);font-size:13px;">\${i.quantity || 1}x</span>
                    <span style="font-weight:700;color:var(--text-light);font-size:13.5px;">\${itemName}</span>
                    \${kitchenBadge}
                  </div>
                  \${customsHtml}
                  \${notesText}
                </div>
                <div style="font-weight:700;color:#FFFFFF;font-size:13.5px;white-space:nowrap;">
                  ₱\${Math.round(itemPrice || 0)}
                </div>
              </div>
            `;
          }).join('');
        }
      }

      modal.style.display = 'flex';
    }

    function toggleTrackerOrderDetails() {
      openOrderDetailsModal();
    }

    function startOrderTracking(orderId, orderNumber, total, items, initialStatus) {
      const prevOrderId = activeTrackedOrderId;
      const prevOrderNum = activeTrackedOrderNum;
      activeTrackedOrderId = orderId;
      activeTrackedOrderNum = orderNumber;
      const statusToUse = initialStatus || 'pending';
      if (items && Array.isArray(items)) {
        activeTrackedItems = items;
      }

      // Reset alarm dismissal if different order or if status is not ready
      const newCleanId = String(orderId || '').replace('#', '').trim();
      const newCleanNum = String(orderNumber || '').replace('#', '').trim();
      const isDifferentOrder = (!prevOrderId || (newCleanId && newCleanId !== String(prevOrderId).replace('#', '').trim())) ||
                              (!prevOrderNum || (newCleanNum && newCleanNum !== String(prevOrderNum).replace('#', '').trim()));

      if (isDifferentOrder || statusToUse !== 'ready') {
        stopAlarm(null, false);
        isAlarmPermanentlyDismissed = false;
        dismissedOrderNumber = null;
        dismissedOrderId = null;
        try {
          _store.removeItem('alarmDismissed_global');
          if (orderNumber) {
            _store.removeItem('alarmDismissed_' + orderNumber);
            _store.removeItem('alarmDismissed_' + newCleanNum);
            _store.removeItem('alarmDismissed_#' + newCleanNum);
          }
          if (orderId) {
            _store.removeItem('alarmDismissed_' + orderId);
            _store.removeItem('alarmDismissed_' + newCleanId);
          }
          _store.removeItem('alarmDismissed_#1');
          _store.removeItem('alarmDismissed_1');
          _store.removeItem('alarmDismissed_#2');
          _store.removeItem('alarmDismissed_2');
        } catch(e) {}
      }

      try {
        _store.setItem('activeOrderId', orderId);
        _store.setItem('activeOrderNum', orderNumber);
        _store.setItem('activeOrderTotal', total);
        _store.setItem('activeTableNumber', currentTable);
        if (items && items.length > 0) {
          _store.setItem('activeOrderItems', JSON.stringify(items));
        }
        _store.removeItem('pendingCart');
        if (isDifferentOrder) {
          _store.removeItem('custVolumeSeen_current');
          _store.removeItem('custPaymentVolumeSeen_current');
          _store.removeItem('custVolumeSeen_1');
          _store.removeItem('custPaymentVolumeSeen_1');
          _store.removeItem('custVolumeSeen_active_order');
          _store.removeItem('custPaymentVolumeSeen_active_order');
          try {
            sessionStorage.removeItem('custVolumeSeen_current');
            sessionStorage.removeItem('custPaymentVolumeSeen_current');
          } catch(_s) {}
        }
      } catch(e) {}

      // Keep browser URL cleanly in sync with active table & order
      try {
        const cleanT = String(currentTable || '').replace(/[^0-9]/g, '').trim();
        const fullT = (cleanT && currentTableToken) ? ('T' + cleanT + '-' + currentTableToken) : cleanT;
        const cleanN = String(orderNumber || '').replace('#', '').trim();
        const targetSearch = (fullT && cleanN)
            ? ('?table=' + encodeURIComponent(fullT) + '&order=' + encodeURIComponent(cleanN))
            : (fullT ? ('?table=' + encodeURIComponent(fullT)) : (cleanN ? ('?order=' + encodeURIComponent(cleanN)) : ''));
        if (targetSearch && window.location.search !== targetSearch) {
          window.history.replaceState({ orderId, orderNumber, table: currentTable, token: currentTableToken }, document.title, window.location.pathname + targetSearch);
        }
      } catch(_) {}

      document.getElementById('controlsWrapper').style.display = 'none';
      document.getElementById('menuView').style.display = 'none';
      document.getElementById('cartBar').style.display = 'none';
      document.getElementById('trackerView').style.display = 'block';
      const isCompleteOrCancelled = (statusToUse === 'completed' || statusToUse === 'cancelled');

      // Hide previous ready alert notice banner on new order tracking
      const readyNotice = document.getElementById('readyNotice');
      if (readyNotice && statusToUse !== 'ready') {
        readyNotice.style.display = 'none';
      }
      const readyNum = document.getElementById('readyNoticeOrderNum');
      if (readyNum) readyNum.innerText = orderNumber || '#1';

      document.getElementById('trackOrderNum').innerText = orderNumber;
      const promptNum = document.getElementById('promptOrderNum');
      if (promptNum) promptNum.innerText = orderNumber;
      const isTk = currentOrderType === 'takeaway' || String(currentTable).toLowerCase().includes('take');
      const tableLabel = isTk ? 'Take Out' : `\${currentTable} (Dine-In at Table)`;
      const tableInfoEl = document.getElementById('trackTableInfo');
      if (tableInfoEl) tableInfoEl.innerText = tableLabel;
      const trackTotalEl = document.getElementById('trackTotal');
      if (trackTotalEl) trackTotalEl.innerText = `₱\${Math.round(total)}.00`;

      const barcodeSerialEl = document.getElementById('ticketBarcodeSerial');
      if (barcodeSerialEl) {
        const numClean = String(orderNumber || '1').replace(/[^0-9]/g, '');
        const padded = numClean ? numClean.padStart(4, '0') : '0001';
        barcodeSerialEl.innerText = `* CC-ORD-\${padded}-LIVE *`;
      }

      // Generate prominent thermal receipt QR Code
      const qrImg = document.getElementById('receiptQrImg');
      if (qrImg) {
        const numClean = String(orderNumber || '1').replace(/[^0-9]/g, '');
        const padded = numClean ? numClean.padStart(4, '0') : '0001';
        const qrData = window.location.href || ('CC-ORDER-' + padded);
        qrImg.src = '/api/qr?data=' + encodeURIComponent(qrData);
        qrImg.onerror = function() {
          this.src = 'https://api.qrserver.com/v1/create-qr-code/?size=220x220&data=' + encodeURIComponent(qrData);
        };
      }

      // Trigger/re-trigger downward thermal print feed animation
      const paperEl = document.getElementById('thermalReceiptPaper');
      if (paperEl) {
        paperEl.classList.remove('printing-feed-anim');
        void paperEl.offsetWidth; // Force reflow
        paperEl.classList.add('printing-feed-anim');
      }

      const cancelBtn = document.getElementById('btnCancelOrder');
      if (cancelBtn) {
        cancelBtn.innerHTML = '<svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="#FFFFFF" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"></circle><line x1="15" y1="9" x2="9" y2="15"></line><line x1="9" y1="9" x2="15" y2="15"></line></svg><span style="color: #FFFFFF; font-weight: 700;">Cancel Order</span>';
        cancelBtn.disabled = false;
      }

      renderTrackedItemsList(activeTrackedItems, total);
      updateTrackerUI(statusToUse);

      // Keep screen awake while tracking order so phone doesn't sleep
      try {
        if ('wakeLock' in navigator) {
          navigator.wakeLock.request('screen').catch(() => {});
        }
      } catch(_) {}

      // Only prompt customer to turn up volume if the order is ALREADY settled/confirmed by cashier (never when pending!)
      const isSettledOrder = ['confirmed', 'inqueue', 'queue', 'preparing', 'brewing', 'kitchen'].includes((statusToUse || '').toLowerCase());
      if (isSettledOrder) {
        setTimeout(() => showCustomerVolumeModal(false), 350);
      }

      if (pollInterval) clearInterval(pollInterval);
      if (statusToUse !== 'completed' && statusToUse !== 'cancelled') {
        checkOrderStatus();
        pollInterval = setInterval(checkOrderStatus, 1500);
      }
    }

    let slowFetchTimer = null;

    function checkOrderStatus() {
      if (!activeTrackedOrderId && !activeTrackedOrderNum) return;
      const qId = activeTrackedOrderId || activeTrackedOrderNum;

      if (slowFetchTimer) clearTimeout(slowFetchTimer);
      slowFetchTimer = setTimeout(() => {
        const slowBanner = document.getElementById('slowConnectionBanner');
        if (slowBanner && prevTrackStatus !== 'completed') {
          slowBanner.style.display = 'block';
        }
      }, 1200);

      fetch(`/api/order-status?orderId=\${encodeURIComponent(qId)}`)
        .then(r => r.json())
        .then(data => {
          if (slowFetchTimer) clearTimeout(slowFetchTimer);
          const slowBanner = document.getElementById('slowConnectionBanner');
          if (slowBanner) slowBanner.style.display = 'none';
          const banner = document.getElementById('wifiWarningBanner');
          if (banner) banner.style.display = 'none';

          if (!activeTrackedOrderId && !activeTrackedOrderNum) return;

          if (!data) return;

          // Order not found in cafe records (cleared, deleted or invalid)
          if (data.status === 'not_found' || data.success === false || (data.error && data.error.toLowerCase().includes('not found'))) {
            if (pollInterval) { clearInterval(pollInterval); pollInterval = null; }
            showSuccessModal({
              title: 'Order Notice',
              message: 'Order not found in cafe records. Please place a new order.',
              buttonText: 'OK',
              onDismiss: () => newOrder(true)
            });
            return;
          }

          // Order explicitly cancelled by cashier
          if (data.status === 'cancelled') {
            if (pollInterval) { clearInterval(pollInterval); pollInterval = null; }
            showSuccessModal({
              title: 'Order Cancelled',
              message: 'Your order was cancelled by the cashier. You can now place a new order.',
              buttonText: 'Return to Menu',
              onDismiss: () => newOrder(true)
            });
            return;
          }

          if (data && data.success) {
            activeReceiptData = data;
            try { _store.setItem('activeReceiptData', JSON.stringify(data)); } catch(e) {}
          }
          updateTrackerUI(data.status);
          if (data.items && Array.isArray(data.items) && data.items.length > 0) {
            activeTrackedItems = data.items;
            try { _store.setItem('activeOrderItems', JSON.stringify(data.items)); } catch(e) {}
            renderTrackedItemsList(data.items, data.totalAmount);
          }
          renderLiveQueue(data.currentlyPreparing, data.currentlyInQueue, data.currentlyReady);
        })
        .catch(e => {
          if (slowFetchTimer) clearTimeout(slowFetchTimer);
          const slowBanner = document.getElementById('slowConnectionBanner');
          if (slowBanner && navigator.onLine) {
            slowBanner.style.display = 'block';
          }
          const banner = document.getElementById('wifiWarningBanner');
          if (banner && !navigator.onLine) {
            banner.style.display = 'block';
          }
        });
    }

    function refreshLiveQueueModal() {
      const qIcon = document.getElementById('queueRefreshIcon');
      if (qIcon) qIcon.style.animation = 'spin 0.6s linear infinite';
      fetch('/api/order-status')
        .then(r => r.json())
        .then(data => {
          if (data) {
            renderLiveQueue(data.currentlyPreparing, data.currentlyInQueue, data.currentlyReady);
          }
        })
        .catch(() => {})
        .finally(() => {
          if (qIcon) {
            setTimeout(() => { qIcon.style.animation = 'none'; }, 600);
          }
        });
    }

    function openKitchenQueueModal() {
      const modal = document.getElementById('kitchenQueueModal');
      if (modal) modal.style.display = 'flex';
      refreshLiveQueueModal();
    }

    function parseChipItem(raw) {
      if (typeof raw === 'object' && raw !== null) {
        const num = raw.orderNumber || '';
        let tbl = (raw.tableNumber || '').trim();
        tbl = tbl.replace(/^T+able/i, 'Table');
        const isTakeout = raw.orderType === 'takeaway' || raw.orderType === 'delivery' || tbl.toLowerCase().includes('take');
        return {
          orderNum: num,
          tableText: isTakeout ? 'Takeout' : (tbl ? (tbl.toLowerCase().startsWith('table') ? tbl : 'Table ' + tbl) : ''),
          isTakeout: isTakeout
        };
      }

      const str = String(raw || '').trim();
      const parts = str.split(' ·').map(s => s.trim());
      const num = parts[0] || '';
      let tbl = '';

      for (let i = 1; i < parts.length; i++) {
        const p = parts[i];
        if (p.toUpperCase() !== 'KITCHEN' && p) {
          tbl = p.replace(/^T+able/i, 'Table');
        }
      }

      const isTakeout = tbl.toLowerCase().includes('take');
      if (tbl && !isTakeout && !tbl.toLowerCase().startsWith('table')) {
        tbl = 'Table ' + tbl;
      }

      return {
        orderNum: num,
        tableText: tbl,
        isTakeout: isTakeout
      };
    }

    function renderChipHtml(chip, statusType, currentNum) {
      const cleanChipNum = (chip.orderNum || '').toLowerCase();
      const cleanMyNum = (currentNum || '').toLowerCase();
      const isMine = cleanMyNum && (
        cleanChipNum === cleanMyNum ||
        cleanChipNum.replace('#','').trim() === cleanMyNum.replace('#','').trim()
      );

      let badgeColor = '#D97706';
      let bgStyle = 'background: rgba(217, 119, 6, 0.09);';
      let borderStyle = 'border: 1px solid rgba(217, 119, 6, 0.28);';

      if (isMine) {
        badgeColor = '#FFFFFF';
        bgStyle = 'background: rgba(196, 130, 72, 0.22);';
        borderStyle = 'border: 1.5px solid #C48248;';
      } else if (statusType === 'ready') {
        badgeColor = '#86EFAC';
        bgStyle = 'background: rgba(34, 197, 94, 0.1);';
        borderStyle = 'border: 1px solid rgba(34, 197, 94, 0.25);';
      } else if (statusType === 'queue') {
        badgeColor = '#E5E0DA';
        bgStyle = 'background: rgba(255, 255, 255, 0.04);';
        borderStyle = 'border: 1px solid rgba(255, 255, 255, 0.1);';
      }

      const tableBadge = chip.tableText
        ? `<span style="font-size: 11px; font-weight: 700; color: \${isMine ? '#FFFFFF' : 'var(--text-muted)'}; display: inline-flex; align-items: center; gap: 4px; background: rgba(0,0,0,0.25); padding: 2px 7px; border-radius: 6px;">
            \${chip.isTakeout ? '<svg width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M6 2L3 6v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2V6l-3-4z"></path></svg>' : '<svg width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><circle cx="12" cy="12" r="10"></circle></svg>'} <span>\${chip.tableText}</span>
           </span>`
        : '';

      return `
        <div style="\${bgStyle} \${borderStyle} border-radius: 12px; padding: 7px 12px; display: inline-flex; align-items: center; gap: 7px;">
          <span style="font-family: 'Outfit', sans-serif; font-weight: 800; font-size: 13.5px; color: \${isMine ? '#FFFFFF' : badgeColor}; letter-spacing: 0.3px;">
            \${chip.orderNum}
          </span>
          \${tableBadge}
        </div>
      `;
    }

    function renderLiveQueue(preparingList, queueList, readyList) {
      const nowPrepContainer = document.getElementById('modalNowPreparingChips');
      const inQueueContainer = document.getElementById('modalInQueueChips');
      const readyContainer = document.getElementById('modalReadyChips');
      const nowPrepCount = document.getElementById('modalNowPrepCount');
      const inQueueCount = document.getElementById('modalInQueueCount');
      const readyCount = document.getElementById('modalReadyCount');
      const summaryBadge = document.getElementById('trackerQueueSummaryBadge');
      const headerQueueText = document.getElementById('headerQueueText');

      const currentNum = (activeTrackedOrderNum || _store.getItem('activeOrderNum') || '').trim();
      const preps = (Array.isArray(preparingList) ? preparingList : []).map(parseChipItem).filter(c => c.orderNum);
      const queue = (Array.isArray(queueList) ? queueList : []).map(parseChipItem).filter(c => c.orderNum);
      const ready = (Array.isArray(readyList) ? readyList : []).map(parseChipItem).filter(c => c.orderNum);

      if (summaryBadge) {
        summaryBadge.innerText = `\${preps.length} brewing • \${queue.length} in queue`;
      }
      if (headerQueueText) {
        headerQueueText.innerText = preps.length > 0 ? `\${preps.length} Brewing` : (queue.length > 0 ? `\${queue.length} in Queue` : 'Kitchen Queue');
      }
      if (nowPrepCount) nowPrepCount.innerText = `\${preps.length} order\${preps.length !== 1 ? 's' : ''}`;
      if (inQueueCount) inQueueCount.innerText = `\${queue.length} order\${queue.length !== 1 ? 's' : ''}`;
      if (readyCount) readyCount.innerText = `\${ready.length} ready`;

      // Customer Active Order Hero Highlight inside Modal
      const activeBanner = document.getElementById('modalActiveOrderBanner');
      if (activeBanner) {
        if (currentNum) {
          const isPrep = preps.some(p => p.orderNum.toLowerCase() === currentNum.toLowerCase() || p.orderNum.replace('#','').trim() === currentNum.replace('#','').trim());
          const isQ = queue.some(p => p.orderNum.toLowerCase() === currentNum.toLowerCase() || p.orderNum.replace('#','').trim() === currentNum.replace('#','').trim());
          const isR = ready.some(p => p.orderNum.toLowerCase() === currentNum.toLowerCase() || p.orderNum.replace('#','').trim() === currentNum.replace('#','').trim());
          
          let myStatusLabel = 'Awaiting Cashier Confirmation';
          let myStatusColor = '#D4A373';
          if (isPrep) { myStatusLabel = 'Now Brewing & Preparing'; myStatusColor = '#D97706'; }
          else if (isR) { myStatusLabel = 'Ready for Pickup Counter!'; myStatusColor = '#22C55E'; }
          else if (isQ) { myStatusLabel = 'In Kitchen Preparation Queue'; myStatusColor = '#E5E0DA'; }

          activeBanner.style.display = 'block';
          activeBanner.innerHTML = `
            <div style="background: rgba(255,255,255,0.04); border: 1px solid rgba(196,130,72,0.35); border-radius: 14px; padding: 10px 14px; margin-bottom: 14px; display: flex; align-items: center; justify-content: space-between; gap: 8px;">
              <div>
                <div style="font-size: 10.5px; font-weight: 800; color: #A89B91; text-transform: uppercase; letter-spacing: 0.5px;">Your Order Number</div>
                <div style="font-size: 16px; font-weight: 900; color: #FFFFFF; font-family: 'Outfit', sans-serif;">\${currentNum}</div>
              </div>
              <span style="font-size: 11px; font-weight: 700; color: \${myStatusColor}; background: rgba(0,0,0,0.3); border: 1px solid rgba(255,255,255,0.08); padding: 4px 10px; border-radius: 8px;">\${myStatusLabel}</span>
            </div>
          `;
        } else {
          activeBanner.style.display = 'none';
        }
      }

      if (nowPrepContainer) {
        if (preps.length === 0) {
          nowPrepContainer.innerHTML = '<div style="display: flex; align-items: center; gap: 8px; color: var(--text-muted); font-size: 12px; padding: 6px 2px;"><svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M18 8h1a4 4 0 0 1 0 8h-1"></path><path d="M2 8h16v9a4 4 0 0 1-4 4H6a4 4 0 0 1-4-4V8z"></path></svg> <span>Barista station is standing by for new items</span></div>';
        } else {
          nowPrepContainer.innerHTML = preps.map(item => renderChipHtml(item, 'preparing', currentNum)).join('');
        }
      }

      if (inQueueContainer) {
        if (queue.length === 0) {
          inQueueContainer.innerHTML = '<div style="display: flex; align-items: center; gap: 8px; color: var(--text-muted); font-size: 12px; padding: 6px 2px;"><svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"></circle><polyline points="12 6 12 12 14 14"></polyline></svg> <span>Queue is clear — orders start prep immediately!</span></div>';
        } else {
          inQueueContainer.innerHTML = queue.map(item => renderChipHtml(item, 'queue', currentNum)).join('');
        }
      }

      if (readyContainer) {
        if (ready.length === 0) {
          readyContainer.innerHTML = '<div style="display: flex; align-items: center; gap: 8px; color: var(--text-muted); font-size: 12px; padding: 6px 2px;"><svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9"></path><path d="M13.73 21a2 2 0 0 1-3.46 0"></path></svg> <span>All prepared orders have been collected</span></div>';
        } else {
          readyContainer.innerHTML = ready.map(item => renderChipHtml(item, 'ready', currentNum)).join('');
        }
      }
    }

    window.addEventListener('offline', () => {
      const banner = document.getElementById('wifiWarningBanner');
      if (banner) banner.style.display = 'block';
    });
    window.addEventListener('online', () => {
      const banner = document.getElementById('wifiWarningBanner');
      if (banner) banner.style.display = 'none';
    });

    function renderTrackedItemsList(items, total) {
      const countEl = document.getElementById('trackedItemsCount');
      const modalListEl = document.getElementById('modalOrderItemsList');
      const modalTotalEl = document.getElementById('modalReceiptTotal');
      const trackerListEl = document.getElementById('trackerOrderDetailsList');

      const itemList = items || [];
      const totalQty = itemList.reduce((sum, i) => sum + (i.quantity || 1), 0);
      if (countEl) countEl.innerText = totalQty;
      if (modalTotalEl && total) modalTotalEl.innerText = `₱\${Math.round(total)}`;

      // Update thermal receipt total amount
      if (total !== undefined && total !== null) {
        const trackTotalEl = document.getElementById('trackTotal');
        if (trackTotalEl) trackTotalEl.innerText = `₱\${Math.round(total)}.00`;
      }

      // Populate authentic thermal receipt item rows
      const receiptItemsEl = document.getElementById('receiptItemsContainer');
      if (receiptItemsEl) {
        if (itemList.length === 0) {
          receiptItemsEl.innerHTML = `
            <div class="receipt-item-line">
              <span class="receipt-item-name">1x Cafe Order Placed</span>
              <span class="receipt-item-price">₱\${Math.round(total || 0)}.00</span>
            </div>
          `;
        } else {
          receiptItemsEl.innerHTML = itemList.map(i => {
            const itemName = i.name || i.menuItem?.name || 'Item';
            const itemPrice = i.price || i.totalPrice || ((i.unitPrice || 0) * (i.quantity || 1));
            return `
              <div class="receipt-item-line">
                <span class="receipt-item-name">\${i.quantity || 1}x \${itemName}</span>
                <span class="receipt-item-price">₱\${Math.round(itemPrice || 0)}.00</span>
              </div>
            `;
          }).join('');
        }
      }

      // Render into collapsible tracker accordion list
      if (trackerListEl) {
        if (itemList.length === 0) {
          trackerListEl.innerHTML = '<div style="font-size:12.5px;color:var(--text-muted);text-align:center;padding:12px;">Order details registered with Cashier.</div>';
        } else {
          trackerListEl.innerHTML = itemList.map(i => {
            const itemName = i.name || i.menuItem?.name || 'Item';
            const customsList = i.customizations || [];
            const customsText = customsList.map(c => typeof c === 'string' ? c : (c.optionName || c.name || '')).filter(Boolean).join(', ');
            const notesText = i.notes ? `<div style="font-size:11px;color:var(--rose);margin-top:3px;font-weight:600;">Note: "\${i.notes}"</div>` : '';
            const customsHtml = customsText ? `<div style="font-size:11.5px;color:#A89B91;margin-top:2px;">› \${customsText}</div>` : '';
            const itemPrice = i.price || i.totalPrice || ((i.unitPrice || 0) * (i.quantity || 1));
            return `
              <div style="display:flex;justify-content:space-between;align-items:flex-start;padding:8px 0;border-bottom:1px solid rgba(255,255,255,0.06);">
                <div style="flex:1;padding-right:12px;">
                  <div style="display:flex;align-items:center;gap:6px;">
                    <span style="font-weight:800;color:var(--caramel-accent);font-size:12.5px;">\${i.quantity || 1}x</span>
                    <span style="font-weight:700;color:var(--text-light);font-size:13.5px;">\${itemName}</span>
                  </div>
                  \${customsHtml}
                  \${notesText}
                </div>
                <div style="font-weight:700;color:#FFFFFF;font-size:13.5px;white-space:nowrap;">
                  ₱\${Math.round(itemPrice || 0)}
                </div>
              </div>
            `;
          }).join('');
        }
      }

      if (!modalListEl) return;
      if (itemList.length === 0) {
        modalListEl.innerHTML = '<div style="font-size:12.5px;color:var(--text-muted);text-align:center;padding:16px;">Order details registered with Cashier.</div>';
        return;
      }

      modalListEl.innerHTML = itemList.map(i => {
        const itemName = i.name || i.menuItem?.name || 'Item';
        const isKitchen = i.isKitchen === true ||
          ['streetBites', 'pastaDishes', 'sandwich', 'dinner'].includes((i.category || '').toLowerCase()) ||
          ['wings', 'buffalo', 'fries', 'stick', 'lumpia', 'shanghai', 'pasta', 'carbonara', 'aglio', 'sandwich', 'toast', 'bbq', 'barbeque', 'combo', 'rice', 'inasal', 'sisig'].some(k => itemName.toLowerCase().includes(k));
        const kitchenBadge = isKitchen ? '<span style="background:rgba(255,87,34,0.22);border:1px solid rgba(255,87,34,0.55);color:#FF7043;font-size:10px;font-weight:900;padding:2px 6px;border-radius:4px;margin-left:6px;">KITCHEN</span>' : '';

        const customsList = i.customizations || [];
        const customsText = customsList.map(c => typeof c === 'string' ? c : (c.optionName || c.name || '')).filter(Boolean).join(', ');
        const notesText = i.notes ? `<div style="font-size:11px;color:var(--rose);margin-top:3px;font-weight:600;">Note: "\${i.notes}"</div>` : '';
        const customsHtml = customsText ? `<div style="font-size:11.5px;color:var(--text-muted);margin-top:2px;">› \${customsText}</div>` : '';
        const itemPrice = i.price || i.totalPrice || ((i.unitPrice || 0) * (i.quantity || 1));

        return `
          <div style="display:flex;justify-content:space-between;align-items:flex-start;padding:8px 0;border-bottom:1px solid rgba(255,255,255,0.06);">
            <div style="flex:1;padding-right:12px;">
              <div style="display:flex;align-items:center;gap:6px;">
                <span style="font-weight:800;color:var(--gold-primary);font-size:12.5px;">\${i.quantity || 1}x</span>
                <span style="font-weight:700;color:\${isKitchen ? '#FFE0B2' : 'var(--text-light)'};font-size:13.5px;">\${itemName}</span>
                \${kitchenBadge}
              </div>
              \${customsHtml}
              \${notesText}
            </div>
            <div style="font-weight:700;color:var(--gold-light);font-size:13.5px;white-space:nowrap;">
              ₱\${Math.round(itemPrice || 0)}
            </div>
          </div>
        `;
      }).join('');
    }

    function openOrderModal() {
      const r = activeReceiptData || {};
      const s = (r.status || prevTrackStatus || 'pending').toLowerCase();
      const isPaid = (s === 'confirmed' || s === 'inqueue' || s === 'queue' || s === 'preparing' || s === 'brewing' || s === 'kitchen' || s === 'ready' || s === 'completed');

      if (!isPaid) {
        // Do not display receipt if not settled by cashier
        return;
      }

      const modal = document.getElementById('orderReceiptModal');
      const stampBadge = document.getElementById('receiptStampBadge');
      const orderNumEl = document.getElementById('receiptOrderNum');
      const dateTimeEl = document.getElementById('receiptDateTime');
      const tableTypeEl = document.getElementById('receiptTableType');
      const cashierEl = document.getElementById('receiptCashierName');
      const custEl = document.getElementById('receiptCustName');
      const subtotalEl = document.getElementById('receiptSubtotal');
      const discountRow = document.getElementById('receiptDiscountRow');
      const discountLabel = document.getElementById('receiptDiscountLabel');
      const discountAmountEl = document.getElementById('receiptDiscountAmount');
      const grandTotalEl = document.getElementById('receiptGrandTotal');
      const payDetails = document.getElementById('receiptPaymentDetails');
      const payMethodEl = document.getElementById('receiptPayMethod');
      const tenderedEl = document.getElementById('receiptTendered');
      const changeDueEl = document.getElementById('receiptChangeDue');

      const orderNum = r.orderNumber || activeTrackedOrderNum || '#1';

      if (orderNumEl) orderNumEl.innerText = orderNum;
      const isTkReceipt = (r.orderType === 'takeaway' || r.orderType === 'takeout' || (r.tableNumber && r.tableNumber.toLowerCase().includes('take')) || currentOrderType === 'takeaway');
      if (tableTypeEl) tableTypeEl.innerText = isTkReceipt ? 'Take Out' : `\${r.tableNumber || currentTable} • Dine-In`;
      if (cashierEl) cashierEl.innerText = r.cashierName || (isPaid ? 'Cashier Staff' : 'Awaiting Cashier');
      if (custEl) custEl.innerText = r.customerName || 'Guest Patron';

      let dStr = '--';
      if (r.createdAt) {
        try {
          const d = new Date(r.createdAt);
          dStr = d.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' }) + ' • ' + d.toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit', hour12: true });
        } catch(_) {}
      } else {
        const d = new Date();
        dStr = d.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' }) + ' • ' + d.toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit', hour12: true });
      }
      if (dateTimeEl) dateTimeEl.innerText = dStr;

      if (stampBadge) {
        if (isPaid) {
          stampBadge.innerHTML = '✓ OFFICIAL RECEIPT • PAID';
          stampBadge.style.borderColor = '#2EC4B6';
          stampBadge.style.color = '#2EC4B6';
          stampBadge.style.background = 'rgba(46,196,182,0.14)';
        } else {
          stampBadge.innerHTML = '⏳ AWAITING CASHIER CONFIRMATION & PAYMENT';
          stampBadge.style.borderColor = 'var(--gold-primary)';
          stampBadge.style.color = 'var(--gold-light)';
          stampBadge.style.background = 'rgba(212,175,55,0.12)';
        }
      }

      const totalVal = parseFloat(r.totalAmount || _store.getItem('activeOrderTotal') || 0);
      const subtotalVal = parseFloat(r.subtotal || totalVal);
      const discountVal = parseFloat(r.discountAmount || 0);

      if (subtotalEl) subtotalEl.innerText = `₱\${Math.round(subtotalVal)}`;
      if (grandTotalEl) grandTotalEl.innerText = `₱\${Math.round(totalVal)}`;

      if (discountRow) {
        if (discountVal > 0) {
          discountRow.style.display = 'flex';
          if (discountLabel) {
            const pct = r.discountPercentage ? ` (\${r.discountPercentage}%)` : '';
            discountLabel.innerText = `Discount\${pct}:`;
          }
          if (discountAmountEl) discountAmountEl.innerText = `-₱\${Math.round(discountVal)}`;
        } else {
          discountRow.style.display = 'none';
        }
      }

      if (payDetails) {
        if (isPaid) {
          payDetails.style.display = 'block';
          if (payMethodEl) payMethodEl.innerText = (r.paymentMethod || 'Cash').toUpperCase();
          if (tenderedEl) tenderedEl.innerText = `₱\${Math.round(parseFloat(r.amountTendered || totalVal))}`;
          if (changeDueEl) changeDueEl.innerText = `₱\${Math.round(parseFloat(r.changeDue || 0))}`;
        } else {
          payDetails.style.display = 'none';
        }
      }

      renderTrackedItemsList(r.items || activeTrackedItems, totalVal);

      if (modal) modal.style.display = 'flex';
    }

    function updateTrackerUI(status) {
      const s = (status || '').toLowerCase();
      const step1 = document.getElementById('step1');
      const step2 = document.getElementById('step2');
      const step3 = document.getElementById('step3');
      const pendingNotice = document.getElementById('pendingPaymentNotice');
      const confirmedNotice = document.getElementById('confirmedPaymentNotice');
      const brewingNotice = document.getElementById('brewingNotice');
      const compNotice = document.getElementById('completedNotice');
      const readyNotice = document.getElementById('readyNotice');
      const headerTag = document.getElementById('trackerHeaderTag');
      const pendingActions = document.getElementById('pendingActionButtons');
      const instTitle = document.getElementById('trackerInstructionTitle');
      const instStatus = document.getElementById('trackerStatusDisplay');
      const waitTime = document.getElementById('trackerWaitTime');
      const currentOrderDisplayNum = activeTrackedOrderNum || _store.getItem('activeOrderNum') || '#1';

      const barcodeEl = document.getElementById('ticketBarcodeSerial');
      if (barcodeEl) {
        const numClean = String(currentOrderDisplayNum || '1').replace(/[^0-9]/g, '');
        const padded = numClean ? numClean.padStart(4, '0') : '0001';
        barcodeEl.innerText = `* CC-ORD-\${padded}-LIVE *`;
      }

      const qrImg = document.getElementById('receiptQrImg');
      if (qrImg) {
        const numClean = String(currentOrderDisplayNum || '1').replace(/[^0-9]/g, '');
        const padded = numClean ? numClean.padStart(4, '0') : '0001';
        const qrData = window.location.href || ('CC-ORDER-' + padded);
        const expectedSrc = '/api/qr?data=' + encodeURIComponent(qrData);
        if (!qrImg.src || !qrImg.src.includes(encodeURIComponent(qrData))) {
          qrImg.src = expectedSrc;
          qrImg.onerror = function() {
            this.src = 'https://api.qrserver.com/v1/create-qr-code/?size=220x220&data=' + encodeURIComponent(qrData);
          };
        }
      }

      const instCard = document.getElementById('trackerInstructionCard');

      const orderAnotherBtn = document.getElementById('btnOrderAnotherItem');
      const btnOpenOrderModal = document.getElementById('btnOpenOrderModal');
      const isPaid = (s === 'confirmed' || s === 'inqueue' || s === 'queue' || s === 'preparing' || s === 'brewing' || s === 'kitchen' || s === 'ready' || s === 'completed');


      if (btnOpenOrderModal) {
        if (isPaid) {
          btnOpenOrderModal.style.display = 'flex';
          btnOpenOrderModal.innerHTML = `<svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" style="color: #16A34A;"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"></path><polyline points="14 2 14 8 20 8"></polyline><line x1="16" y1="13" x2="8" y2="13"></line><line x1="16" y1="17" x2="8" y2="17"></line><polyline points="10 9 9 9 8 9"></polyline></svg><span>View Official Receipt (<span style="color: #16A34A; font-weight: 800;">Paid ✓</span>)</span>`;
          btnOpenOrderModal.style.borderColor = '#22C55E';
          btnOpenOrderModal.style.boxShadow = 'none';
        } else {
          // Do not display receipt if not settled by cashier
          btnOpenOrderModal.style.display = 'none';
        }
      }

      if (s === 'pending') {
        if (headerTag) {
          headerTag.className = 'tracker-status-pill status-pill-pending';
          headerTag.innerHTML = '<svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"></circle><polyline points="12 6 12 12 16 14"></polyline></svg><span>Order Placed • Awaiting Cashier</span>';
        }
        if (instCard) instCard.className = 'tracker-instruction-card';
        if (instTitle) instTitle.innerHTML = 'SHOW ORDER NUMBER <span id="promptOrderNum">' + currentOrderDisplayNum + '</span> AT CASHIER TO PAY AND CONFIRM';
        if (instStatus) instStatus.innerText = 'Awaiting Cashier';
        if (waitTime) waitTime.innerText = '5 Minutes';
        if (pendingNotice) pendingNotice.style.display = 'block';
        if (confirmedNotice) confirmedNotice.style.display = 'none';
        if (brewingNotice) brewingNotice.style.display = 'none';
        if (compNotice) compNotice.style.display = 'none';
        if (readyNotice) readyNotice.style.display = 'none';
        if (pendingActions) pendingActions.style.display = 'block';
        if (orderAnotherBtn) orderAnotherBtn.style.display = 'none';
        step1.className = 'status-step active';
        step2.className = 'status-step';
        step3.className = 'status-step';
      } else if (s === 'confirmed' || s === 'inqueue' || s === 'queue') {
        if (headerTag) {
          headerTag.className = 'tracker-status-pill status-pill-confirmed';
          headerTag.innerHTML = '<svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"></polyline></svg><span>Payment Confirmed • In Queue</span>';
        }
        if (instCard) instCard.className = 'tracker-instruction-card ticket-stamp-confirmed';
        if (instTitle) instTitle.innerHTML = 'ORDER CONFIRMED • IN QUEUE';
        if (instStatus) instStatus.innerText = 'Payment Confirmed';
        if (waitTime) waitTime.innerText = '5-10 Minutes';
        if (pendingNotice) pendingNotice.style.display = 'none';
        if (confirmedNotice) confirmedNotice.style.display = 'block';
        if (brewingNotice) brewingNotice.style.display = 'none';
        if (compNotice) compNotice.style.display = 'none';
        if (readyNotice) readyNotice.style.display = 'none';
        if (pendingActions) pendingActions.style.display = 'none';
        if (orderAnotherBtn) orderAnotherBtn.style.display = 'none';
        step1.className = 'status-step completed';
        step2.className = 'status-step'; // Awaiting barista to tap Start Brewing
        step3.className = 'status-step';

        // Prompt volume notification when cashier confirms payment / settles
        const curNum = activeTrackedOrderNum || _store.getItem('activeOrderNum') || '';
        const curId = activeTrackedOrderId || _store.getItem('activeOrderId') || '';
        const cleanN = String(curNum).replace('#', '').trim();
        const cleanI = String(curId).replace('#', '').trim();

        const hasSeenPaymentVol = (cleanN && (
          sessionStorage.getItem('custPaymentVolumeSeen_' + cleanN) === 'true' ||
          sessionStorage.getItem('custPaymentVolumeSeen_#' + cleanN) === 'true' ||
          sessionStorage.getItem('custVolumeSeen_' + cleanN) === 'true'
        )) || (cleanI && (
          sessionStorage.getItem('custPaymentVolumeSeen_' + cleanI) === 'true' ||
          sessionStorage.getItem('custVolumeSeen_' + cleanI) === 'true'
        ));

        if (!hasSeenPaymentVol) {
          setTimeout(() => showCustomerVolumeModal(false), 350);
        }
      } else if (s === 'preparing' || s === 'brewing' || s === 'kitchen') {
        if (headerTag) {
          headerTag.className = 'tracker-status-pill status-pill-preparing';
          headerTag.innerHTML = '<svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M18 8h1a4 4 0 0 1 0 8h-1"></path><path d="M2 8h16v9a4 4 0 0 1-4 4H6a4 4 0 0 1-4-4V8z"></path><line x1="6" y1="1" x2="6" y2="4"></line><line x1="10" y1="1" x2="10" y2="4"></line><line x1="14" y1="1" x2="14" y2="4"></line></svg><span>Now Brewing & Preparing</span>';
        }
        if (instCard) instCard.className = 'tracker-instruction-card ticket-stamp-brewing';
        if (instTitle) instTitle.innerHTML = 'NOW BREWING & PREPARING';
        if (instStatus) instStatus.innerText = 'Barista at Work';
        if (waitTime) waitTime.innerText = '2-4 Minutes';
        if (pendingNotice) pendingNotice.style.display = 'none';
        if (confirmedNotice) confirmedNotice.style.display = 'none';
        if (brewingNotice) brewingNotice.style.display = 'block';
        if (compNotice) compNotice.style.display = 'none';
        if (readyNotice) readyNotice.style.display = 'none';
        if (pendingActions) pendingActions.style.display = 'none';
        if (orderAnotherBtn) orderAnotherBtn.style.display = 'none';
        step1.className = 'status-step completed';
        step2.className = 'status-step active'; // Step 2 lights up now!
        step3.className = 'status-step';

        // Prompt volume notification when cashier settles payment if not yet seen
        const curNum = activeTrackedOrderNum || _store.getItem('activeOrderNum') || '';
        const curId = activeTrackedOrderId || _store.getItem('activeOrderId') || '';
        const cleanN = String(curNum).replace('#', '').trim();
        const cleanI = String(curId).replace('#', '').trim();

        const hasSeenPaymentVol = (cleanN && (
          sessionStorage.getItem('custPaymentVolumeSeen_' + cleanN) === 'true' ||
          sessionStorage.getItem('custPaymentVolumeSeen_#' + cleanN) === 'true' ||
          sessionStorage.getItem('custVolumeSeen_' + cleanN) === 'true'
        )) || (cleanI && (
          sessionStorage.getItem('custPaymentVolumeSeen_' + cleanI) === 'true' ||
          sessionStorage.getItem('custVolumeSeen_' + cleanI) === 'true'
        ));

        if (!hasSeenPaymentVol) {
          setTimeout(() => showCustomerVolumeModal(false), 350);
        }


      } else if (s === 'ready') {
        if (headerTag) {
          headerTag.className = 'tracker-status-pill status-pill-ready';
          headerTag.innerHTML = '<svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9"></path><path d="M13.73 21a2 2 0 0 1-3.46 0"></path></svg><span>Ready For Pickup!</span>';
        }
        if (instCard) instCard.className = 'tracker-instruction-card ticket-stamp-ready';
        if (instTitle) instTitle.innerHTML = 'ORDER READY FOR PICKUP!';
        if (instStatus) instStatus.innerText = 'Ready at Pickup Counter';
        if (waitTime) waitTime.innerText = 'Ready Now!';
        if (pendingNotice) pendingNotice.style.display = 'none';
        if (confirmedNotice) confirmedNotice.style.display = 'none';
        if (brewingNotice) brewingNotice.style.display = 'none';
        if (readyNotice) {
          readyNotice.style.display = 'block';
          const readyNum = document.getElementById('readyNoticeOrderNum');
          if (readyNum) readyNum.innerText = activeTrackedOrderNum || _store.getItem('activeOrderNum') || '#1';
        }
        const compNotice = document.getElementById('completedNotice');
        if (compNotice) compNotice.style.display = 'none';
        if (pendingActions) pendingActions.style.display = 'none';
        if (orderAnotherBtn) {
          const isOkayClicked = window._readyOkayClicked || isOrderAlarmDismissed() || isAlarmPermanentlyDismissed;
          if (isOkayClicked) {
            orderAnotherBtn.style.display = 'inline-flex';
            orderAnotherBtn.className = 'btn-order-another';
            orderAnotherBtn.innerHTML = '<svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M3 12a9 9 0 0 1 9-9 9.75 9.75 0 0 1 6.74 2.74L21 8"></path><polyline points="21 3 21 8 16 8"></polyline><path d="M21 12a9 9 0 0 1-9 9 9.75 9.75 0 0 1-6.74-2.74L3 16"></path><polyline points="8 16 3 16 3 21"></polyline></svg><span>Order Again</span>';
          } else {
            orderAnotherBtn.style.display = 'none';
          }
        }
        step1.className = 'status-step completed';
        step2.className = 'status-step completed';
        step3.className = 'status-step active';

        // When order enters 'ready' state from any non-ready state, reset stale dismissal
        if (prevTrackStatus !== 'ready') {
          isAlarmPermanentlyDismissed = false;
          dismissedOrderNumber = null;
          dismissedOrderId = null;
          const currentNum = activeTrackedOrderNum || _store.getItem('activeOrderNum') || '';
          const currentId = activeTrackedOrderId || _store.getItem('activeOrderId') || '';
          const cleanNum = String(currentNum).replace('#', '').trim();
          const cleanId = String(currentId).replace('#', '').trim();
          try {
            _store.removeItem('alarmDismissed_global');
            if (cleanNum) {
              _store.removeItem('alarmDismissed_' + cleanNum);
              _store.removeItem('alarmDismissed_#' + cleanNum);
            }
            if (cleanId) {
              _store.removeItem('alarmDismissed_' + cleanId);
            }
            _store.removeItem('alarmDismissed_1');
            _store.removeItem('alarmDismissed_#1');
          } catch(_) {}
        }

        // Trigger alarm if order is ready and not yet dismissed
        if (!isOrderAlarmDismissed()) {
          startRepeatingAlarm();
        }
      } else if (s === 'completed') {
        if (headerTag) {
          headerTag.className = 'tracker-status-pill status-pill-confirmed';
          headerTag.innerHTML = '<svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"></path><polyline points="22 4 12 14.01 9 11.01"></polyline></svg><span>Order Served & Completed</span>';
        }
        if (instTitle) instTitle.innerHTML = 'ORDER SERVED & COMPLETED';
        if (instStatus) instStatus.innerText = 'Served & Enjoy';
        if (waitTime) waitTime.innerText = 'Completed';
        if (pendingNotice) pendingNotice.style.display = 'none';
        if (confirmedNotice) confirmedNotice.style.display = 'none';
        if (brewingNotice) brewingNotice.style.display = 'none';
        if (readyNotice) readyNotice.style.display = 'none';
        const compNotice = document.getElementById('completedNotice');
        if (compNotice) compNotice.style.display = 'block';
        if (pendingActions) pendingActions.style.display = 'none';
        if (orderAnotherBtn) {
          orderAnotherBtn.style.display = 'inline-flex';
          orderAnotherBtn.className = 'btn-order-another';
          orderAnotherBtn.innerHTML = '<svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M3 12a9 9 0 0 1 9-9 9.75 9.75 0 0 1 6.74 2.74L21 8"></path><polyline points="21 3 21 8 16 8"></polyline><path d="M21 12a9 9 0 0 1-9 9 9.75 9.75 0 0 1-6.74-2.74L3 16"></path><polyline points="8 16 3 16 3 21"></polyline></svg><span>Order Again</span>';
        }
        step1.className = 'status-step completed';
        step2.className = 'status-step completed';
        step3.className = 'status-step completed';
        stopAlarm(null, false);

        if (pollInterval) {
          clearInterval(pollInterval);
          pollInterval = null;
        }

        // Pop-up celebratory completed modal with rating & feedback
        showOrderCompletedModal();
      }
      prevTrackStatus = s;
    }

    let completedModalShown = false;
    let currentFeedbackRating = 5;
    const selectedFeedbackTags = new Set(['Delicious Coffee & Drinks', 'Fast & Friendly Service']);
    const ratingDescriptors = {
      5: '⭐⭐⭐⭐⭐ Exceptional & Delicious!',
      4: '⭐⭐⭐⭐ Great Coffee & Service!',
      3: '⭐⭐⭐ Good Visit',
      2: '⭐⭐ Needs a Little Work',
      1: '⭐ Not Up to Standard'
    };

    function renderStarRating(rating) {
      currentFeedbackRating = rating;
      const row = document.getElementById('custStarRow');
      if (!row) return;
      let html = '';
      for (let i = 1; i <= 5; i++) {
        const isFilled = i <= rating;
        const starFill = isFilled ? '#FFB800' : 'none';
        const starStroke = isFilled ? '#FFB800' : 'rgba(255,255,255,0.35)';
        html += `<button type="button" class="cust-star-btn" onclick="setFeedbackRating(\${i})" aria-label="\${i} Stars">
          <svg class="cust-star-svg" viewBox="0 0 24 24" fill="\${starFill}" stroke="\${starStroke}" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2"></polygon>
          </svg>
        </button>`;
      }
      row.innerHTML = html;
      const label = document.getElementById('custRatingDescriptor');
      if (label) {
        label.innerText = ratingDescriptors[rating] || (rating + ' Stars');
      }
    }

    function setFeedbackRating(r) {
      renderStarRating(r);
    }

    function toggleFeedbackChip(el, tag) {
      if (selectedFeedbackTags.has(tag)) {
        selectedFeedbackTags.delete(tag);
        el.classList.remove('active');
      } else {
        selectedFeedbackTags.add(tag);
        el.classList.add('active');
      }
    }

    async function submitCustomerFeedback() {
      const btn = document.getElementById('btnSubmitFeedback');
      const btnText = document.getElementById('btnSubmitFeedbackText');
      if (btn) {
        btn.disabled = true;
        if (btnText) btnText.innerText = 'Saving Feedback...';
      }

      let custName = '';
      try {
        if (typeof activeReceiptData !== 'undefined' && activeReceiptData && activeReceiptData.customerName) {
          custName = activeReceiptData.customerName;
        } else {
          const custNameEl = document.getElementById('custNameInput');
          if (custNameEl && custNameEl.value.trim()) {
            custName = custNameEl.value.trim();
          }
        }
      } catch(_) {}

      const msgInput = document.getElementById('custFeedbackMessageInput');
      const message = msgInput ? msgInput.value.trim() : '';

      const orderId = (typeof activeTrackedOrderId !== 'undefined' && activeTrackedOrderId) 
        ? activeTrackedOrderId 
        : (_store.getItem('activeOrderId') || (typeof activeReceiptData !== 'undefined' && activeReceiptData ? activeReceiptData.orderId : '') || '');

      const orderNum = (typeof activeTrackedOrderNum !== 'undefined' && activeTrackedOrderNum)
        ? activeTrackedOrderNum 
        : (_store.getItem('activeOrderNum') || (typeof activeReceiptData !== 'undefined' && activeReceiptData ? activeReceiptData.orderNumber : '') || '#1');

      const tableNum = (typeof currentTable !== 'undefined' && currentTable)
        ? currentTable 
        : (_store.getItem('activeTableNumber') || (typeof activeReceiptData !== 'undefined' && activeReceiptData ? activeReceiptData.tableNumber : '') || '');

      const payload = {
        orderId: orderId,
        orderNumber: orderNum,
        tableNumber: tableNum,
        customerName: custName || '',
        rating: currentFeedbackRating || 5,
        tags: Array.from(selectedFeedbackTags),
        message: message,
        createdAt: new Date().toISOString()
      };

      const controller = (typeof AbortController !== 'undefined') ? new AbortController() : null;
      const timeoutId = controller ? setTimeout(() => controller.abort(), 6000) : null;

      try {
        await fetch('/api/customer/feedback', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(payload),
          signal: controller ? controller.signal : undefined
        });
      } catch(e) {
        console.warn('Feedback submit network notice:', e);
      } finally {
        if (timeoutId) clearTimeout(timeoutId);
      }

      try {
        const cleanNum = String(orderNum).replace('#', '').trim();
        _store.setItem('custFeedbackSubmitted_' + cleanNum, 'true');
        sessionStorage.setItem('custFeedbackSubmitted_' + cleanNum, 'true');
        _store.removeItem('activeOrderId');
        _store.removeItem('activeOrderNum');
        _store.removeItem('activeOrderTotal');
        _store.removeItem('activeOrderItems');
        _store.removeItem('pendingCart');
        _store.removeItem('orderCompleted');
      } catch(_) {}

      // Switch to thank you view
      const formView = document.getElementById('custFeedbackFormView');
      const successView = document.getElementById('custFeedbackSuccessView');
      if (formView) formView.style.display = 'none';
      if (successView) successView.style.display = 'block';
    }

    function dismissCustomerFeedback(orderAgain = false) {
      try {
        _store.removeItem('activeOrderId');
        _store.removeItem('activeOrderNum');
        _store.removeItem('activeOrderTotal');
        _store.removeItem('activeOrderItems');
        _store.removeItem('pendingCart');
        _store.removeItem('orderCompleted');
      } catch(_) {}
      closeModal('orderCompletedModal');
      newOrder(true);
    }

    function dismissOrderCompleted() {
      dismissCustomerFeedback(true);
    }

    function showOrderCompletedModal() {
      if (completedModalShown) return;
      const compModal = document.getElementById('orderCompletedModal');
      if (!compModal) return;

      const compNum = document.getElementById('completedModalOrderNum');
      const compTable = document.getElementById('completedModalTableInfo');
      const displayNum = (typeof activeTrackedOrderNum !== 'undefined' && activeTrackedOrderNum)
        ? activeTrackedOrderNum
        : (_store.getItem('activeOrderNum') || (typeof activeReceiptData !== 'undefined' && activeReceiptData ? activeReceiptData.orderNumber : '') || '#1');
      if (compNum) compNum.innerText = displayNum;

      const currentT = (typeof currentTable !== 'undefined' && currentTable)
        ? currentTable
        : (_store.getItem('activeTableNumber') || (typeof activeReceiptData !== 'undefined' && activeReceiptData ? activeReceiptData.tableNumber : '') || '1');
      const isTkComp = (currentOrderType === 'takeaway' || (typeof activeReceiptData !== 'undefined' && activeReceiptData && (activeReceiptData.orderType === 'takeaway' || (activeReceiptData.tableNumber && String(activeReceiptData.tableNumber).toLowerCase().includes('take')))));
      if (compTable) compTable.innerText = isTkComp ? 'Take Out' : `Table \${currentT} • Dine-In`;

      // Reset views
      const formView = document.getElementById('custFeedbackFormView');
      const successView = document.getElementById('custFeedbackSuccessView');
      if (formView) formView.style.display = 'block';
      if (successView) successView.style.display = 'none';

      const btn = document.getElementById('btnSubmitFeedback');
      const btnText = document.getElementById('btnSubmitFeedbackText');
      if (btn) btn.disabled = false;
      if (btnText) btnText.innerText = 'Submit Feedback & Rating';

      renderStarRating(currentFeedbackRating || 5);

      compModal.style.display = 'flex';
      compModal.style.zIndex = '99999';
      completedModalShown = true;
    }

    async function cancelCustomerOrder() {
      const targetId = activeTrackedOrderId || activeTrackedOrderNum || _store.getItem('activeOrderId') || _store.getItem('activeOrderNum');
      const orderNum = activeTrackedOrderNum || _store.getItem('activeOrderNum') || '';
      if (!targetId) {
        newOrder();
        return;
      }

      showConfirmModal({
        title: `Cancel Order \${orderNum}?`,
        message: 'This will cancel your pending order at the cashier. Are you sure you want to cancel this order?',
        confirmText: 'Yes, Cancel Order',
        cancelText: 'Keep Order',
        isDestructive: true,
        onConfirm: async () => {
          const currentTargetId = activeTrackedOrderId || activeTrackedOrderNum || _store.getItem('activeOrderId') || _store.getItem('activeOrderNum');
          const currentOrderNum = activeTrackedOrderNum || _store.getItem('activeOrderNum') || '';
          const btn = document.getElementById('btnCancelOrder');
          if (btn) {
            btn.innerHTML = '<span class="btn-spinner"></span><span>Cancelling Order...</span>';
            btn.disabled = true;
          }

          try {
            const payload = {
              orderId: currentTargetId,
              id: currentTargetId,
              orderNumber: currentOrderNum
            };

            const res = await fetch(`/api/customer/cancel-order?orderId=\${encodeURIComponent(currentTargetId)}`, {
              method: 'POST',
              headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify(payload)
            });

            let data = null;
            try {
              data = await res.json();
            } catch (_) {}

            if (btn) {
              btn.innerHTML = '<svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="#FFFFFF" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"></circle><line x1="15" y1="9" x2="9" y2="15"></line><line x1="9" y1="9" x2="15" y2="15"></line></svg><span style="color: #FFFFFF; font-weight: 700;">Cancel Order</span>';
              btn.disabled = false;
            }

            if (data && data.success) {
              try {
                _store.removeItem('activeOrderId');
                _store.removeItem('activeOrderNum');
                _store.removeItem('activeOrderTotal');
                _store.removeItem('activeOrderItems');
                _store.removeItem('pendingCart');
                _store.removeItem('orderCompleted');
              } catch(e) {}
              showSuccessModal({
                title: 'Order Cancelled',
                message: `Order \${currentOrderNum || ''} has been cancelled successfully. You can now place a new order.`,
                buttonText: 'Return to Menu',
                onDismiss: () => newOrder(true)
              });
            } else {
              const errMsg = (data && data.error) ? data.error : 'Cannot cancel order at this time. Please speak with the cashier directly.';
              const isNotFound = errMsg.toLowerCase().includes('not found');
              showSuccessModal({
                title: isNotFound ? 'Order Notice' : 'Cancellation Notice',
                message: isNotFound ? 'Order not found in cafe records. Returning to menu.' : errMsg,
                buttonText: 'OK',
                onDismiss: () => {
                  if (isNotFound) {
                    newOrder(true);
                  } else if (btn) {
                    btn.innerHTML = '<svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="#FFFFFF" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"></circle><line x1="15" y1="9" x2="9" y2="15"></line><line x1="9" y1="9" x2="15" y2="15"></line></svg><span style="color: #FFFFFF; font-weight: 700;">Cancel Order</span>';
                    btn.disabled = false;
                  }
                }
              });
            }
          } catch (err) {
            if (btn) {
              btn.innerHTML = '<svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="#FFFFFF" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"></circle><line x1="15" y1="9" x2="9" y2="15"></line><line x1="9" y1="9" x2="15" y2="15"></line></svg><span style="color: #FFFFFF; font-weight: 700;">Cancel Order</span>';
              btn.disabled = false;
            }
            showSuccessModal({
              title: 'Order Cancelled',
              message: 'Your order has been cancelled.',
              buttonText: 'Return to Menu',
              onDismiss: () => newOrder()
            });
          }
        }
      });
    }

    function newOrder(force = false) {
      if (!force && activeTrackedOrderId && prevTrackStatus && prevTrackStatus !== 'completed' && prevTrackStatus !== 'cancelled') {
        showSuccessModal({
          title: 'Order In Progress',
          message: 'Your order (' + (activeTrackedOrderNum || '') + ') is currently in progress. You cannot place another order until it is completed or cancelled.',
          buttonText: 'View Active Order',
          onDismiss: () => {
            document.getElementById('controlsWrapper').style.display = 'none';
            document.getElementById('menuView').style.display = 'none';
            document.getElementById('cartBar').style.display = 'none';
            document.getElementById('trackerView').style.display = 'block';
            window.scrollTo({ top: 0, behavior: 'smooth' });
          }
        });
        return;
      }
      stopAlarm(null, false);
      window._readyOkayClicked = false;
      isAlarmPermanentlyDismissed = false;
      dismissedOrderNumber = null;
      dismissedOrderId = null;
      if (pollInterval) {
        clearInterval(pollInterval);
        pollInterval = null;
      }
      activeTrackedOrderId = null;
      activeTrackedOrderNum = null;
      activeTrackedItems = [];
      prevTrackStatus = '';
      cart = [];

      try {
        // Clear order-related storage while keeping table assignment intact
        const keys = [];
        for (let i = 0; i < _store.length; i++) {
          const k = _store.key(i);
          if (k && (k.startsWith('alarmDismissed_') || k.startsWith('custVolumeSeen_') || k.startsWith('custPaymentVolumeSeen_'))) keys.push(k);
        }
        keys.forEach(k => _store.removeItem(k));
        _store.removeItem('custVolumeSeen_current');
        _store.removeItem('custPaymentVolumeSeen_current');
        _store.removeItem('custVolumeSeen_1');
        _store.removeItem('custPaymentVolumeSeen_1');
        _store.removeItem('custVolumeSeen_active_order');
        _store.removeItem('custPaymentVolumeSeen_active_order');

        // Also clean up sessionStorage to prevent suppression on subsequent orders
        try {
          if (typeof sessionStorage !== 'undefined') {
            const sessKeys = [];
            for (let i = 0; i < sessionStorage.length; i++) {
              const sk = sessionStorage.key(i);
              if (sk && (sk.startsWith('alarmDismissed_') || sk.startsWith('custVolumeSeen_') || sk.startsWith('custPaymentVolumeSeen_'))) sessKeys.push(sk);
            }
            sessKeys.forEach(sk => sessionStorage.removeItem(sk));
            sessionStorage.removeItem('custVolumeSeen_current');
            sessionStorage.removeItem('custPaymentVolumeSeen_current');
            sessionStorage.removeItem('custVolumeSeen_1');
            sessionStorage.removeItem('custPaymentVolumeSeen_1');
            sessionStorage.removeItem('custVolumeSeen_active_order');
            sessionStorage.removeItem('custPaymentVolumeSeen_active_order');
          }
        } catch(_) {}

        _store.removeItem('activeOrderId');
        _store.removeItem('activeOrderNum');
        _store.removeItem('activeOrderTotal');
        _store.removeItem('activeOrderItems');
        _store.removeItem('activeReceiptData');
        activeReceiptData = null;
        _store.removeItem('orderCompleted');
        _store.removeItem('pendingCart');
      } catch(e) {}

      const btn = document.getElementById('btnSendOrder');
      if (btn) {
        btn.innerText = 'Submit Order to Cashier';
        btn.disabled = false;
      }

      const cancelBtn = document.getElementById('btnCancelOrder');
      if (cancelBtn) {
        cancelBtn.innerHTML = '<svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="#FFFFFF" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"></circle><line x1="15" y1="9" x2="9" y2="15"></line><line x1="9" y1="9" x2="15" y2="15"></line></svg><span style="color: #FFFFFF; font-weight: 700;">Cancel Order</span>';
        cancelBtn.disabled = false;
      }

      const breakdown = document.getElementById('trackedOrderBreakdown');
      if (breakdown) breakdown.style.display = 'none';

      // Reset all notice banners
      const readyNotice = document.getElementById('readyNotice');
      if (readyNotice) readyNotice.style.display = 'none';
      const compNotice = document.getElementById('completedNotice');
      if (compNotice) compNotice.style.display = 'none';
      const pendingNotice = document.getElementById('pendingPaymentNotice');
      if (pendingNotice) pendingNotice.style.display = 'none';
      const confirmedNotice = document.getElementById('confirmedPaymentNotice');
      if (confirmedNotice) confirmedNotice.style.display = 'none';
      const brewingNotice = document.getElementById('brewingNotice');
      if (brewingNotice) brewingNotice.style.display = 'none';

      completedModalShown = false;
      const orderAnotherBtn = document.getElementById('btnOrderAnotherItem');
      if (orderAnotherBtn) {
        orderAnotherBtn.style.display = 'none';
        orderAnotherBtn.className = 'btn-order-another';
      }
      closeModal('trayModal');
      closeModal('customModal');
      closeModal('orderReceiptModal');
      closeModal('confirmModal');
      closeModal('successModal');
      closeModal('readyAlarmModal');
      closeModal('kitchenQueueModal');
      closeModal('orderCompletedModal');
      closeModal('customerVolumeModal');
      isCustVolumeModalOpen = false;

      // Keep browser URL cleanly in sync with active table when returning to menu
      try {
        const cleanT = String(currentTable || '').replace(/[^0-9]/g, '').trim();
        const fullT = (cleanT && currentTableToken) ? ('T' + cleanT + '-' + currentTableToken) : cleanT;
        const targetSearch = fullT ? ('?table=' + encodeURIComponent(fullT)) : '';
        if (window.location.search !== targetSearch) {
          window.history.replaceState({ table: currentTable, token: currentTableToken }, document.title, window.location.pathname + targetSearch);
        }
      } catch(_) {}

      document.getElementById('trackerView').style.display = 'none';
      document.getElementById('controlsWrapper').style.display = 'block';
      document.getElementById('menuView').style.display = 'block';
      const floatingPill = document.getElementById('menuActiveOrderFloatingPill');
      if (floatingPill) floatingPill.style.display = 'none';
      renderMenu();
      updateCartBar();
      window.scrollTo({ top: 0, behavior: 'smooth' });
      try {
        sessionStorage.removeItem('celestial_dining_chosen');
      } catch(e) {}
      setTimeout(showDiningOptionModal, 250);
    }

    function showActiveOrderTracker() {
      document.getElementById('controlsWrapper').style.display = 'none';
      document.getElementById('menuView').style.display = 'none';
      document.getElementById('cartBar').style.display = 'none';
      document.getElementById('trackerView').style.display = 'block';
      window.scrollTo({ top: 0, behavior: 'smooth' });
    }

    function updateActiveOrderFloatingPill() {
      const pill = document.getElementById('menuActiveOrderFloatingPill');
      if (!pill) return;
      const curNum = activeTrackedOrderNum || _store.getItem('activeOrderNum');
      const curStatus = (prevTrackStatus || 'pending').toLowerCase();
      if (curNum && curStatus !== 'completed' && curStatus !== 'cancelled') {
        let statusText = 'Awaiting Cashier';
        if (curStatus === 'confirmed' || curStatus === 'inqueue' || curStatus === 'queue') statusText = 'In Kitchen Queue';
        else if (curStatus === 'preparing' || curStatus === 'brewing' || curStatus === 'kitchen') statusText = 'Now Brewing';
        else if (curStatus === 'ready') statusText = 'Ready for Pickup!';

        const textEl = document.getElementById('floatingOrderPillText');
        if (textEl) textEl.innerText = curNum + ' • ' + statusText;
        pill.style.display = 'block';
      } else {
        pill.style.display = 'none';
      }
    }

    function _verifySavedOrder(savedId, savedNum, savedTotal, savedItems) {
      const qId = savedId || savedNum;
      fetch('/api/order-status?orderId=' + encodeURIComponent(qId))
        .then(r => r.json())
        .then(data => {
          if (data && data.status === 'completed') {
            const itemsToUse = (data.items && Array.isArray(data.items) && data.items.length > 0) ? data.items : savedItems;
            const totalToUse = (data.totalAmount !== undefined && data.totalAmount !== null) ? data.totalAmount : savedTotal;
            startOrderTracking(savedId || savedNum, savedNum || savedId, totalToUse, itemsToUse, 'completed');
            showOrderCompletedModal();
            return;
          }
          if (!data || data.success === false || data.status === 'cancelled' || data.status === 'not_found' || (data.error && data.error.toLowerCase().includes('not found'))) {
            newOrder(true);
            return;
          }
          if (data && data.status) {
            if (data.success) {
              activeReceiptData = data;
              try { _store.setItem('activeReceiptData', JSON.stringify(data)); } catch(e) {}
            }
            const itemsToUse = (data.items && Array.isArray(data.items) && data.items.length > 0) ? data.items : savedItems;
            const totalToUse = (data.totalAmount !== undefined && data.totalAmount !== null) ? data.totalAmount : savedTotal;
            startOrderTracking(savedId || savedNum, savedNum || savedId, totalToUse, itemsToUse, data.status);
            renderLiveQueue(data.currentlyPreparing, data.currentlyInQueue, data.currentlyReady);
          }
        })
        .catch(() => {
          startOrderTracking(savedId || savedNum, savedNum || savedId, savedTotal, savedItems, 'pending');
        });
    }

    function restoreActiveOrderIfAny() {
      try {
        const urlInfo = getUrlParamsInfo();
        const savedId  = _store.getItem('activeOrderId');
        const savedNum = _store.getItem('activeOrderNum');
        const savedTotal = parseFloat(_store.getItem('activeOrderTotal') || '0');
        const savedTable = _store.getItem('activeTableNumber') || _store.getItem('celestial_customer_table');

        let savedItems = [];
        try { savedItems = JSON.parse(_store.getItem('activeOrderItems') || '[]'); } catch(e) {}

        // If URL explicitly specifies a table, enforce currentTable only if verified by actual QR scan
        if (urlInfo.table && isTableVerified && currentTable === urlInfo.table) {
          try { _store.setItem('celestial_customer_table', currentTable); } catch(e) {}
          updateOrderTypeHeaderPill();
          _updateDiningModalUI();
        } else if (urlInfo.table && !isTableVerified) {
          showUnverifiedTableModal(urlInfo.table);
        }

        // ── SCENARIO 1: URL contains an explicit Order parameter (e.g. ?order=2, ?id=..., /track?order=3) ──
        if (urlInfo.order) {
          fetch('/api/order-status?orderId=' + encodeURIComponent(urlInfo.order))
            .then(r => r.json())
            .then(data => {
              if (data && data.success && data.orderId) {
                activeReceiptData = data;
                try { _store.setItem('activeReceiptData', JSON.stringify(data)); } catch(e) {}
                if (data.tableNumber && !data.tableNumber.toLowerCase().includes('take')) {
                  currentTable = data.tableNumber;
                  try { _store.setItem('celestial_customer_table', currentTable); } catch(e) {}
                  updateOrderTypeHeaderPill();
                  _updateDiningModalUI();
                }
                startOrderTracking(data.orderId, data.orderNumber, data.totalAmount || 0, data.items || [], data.status || 'pending');
                renderLiveQueue(data.currentlyPreparing, data.currentlyInQueue, data.currentlyReady);

                try {
                  if ('Notification' in window && Notification.permission !== 'granted' && Notification.permission !== 'denied') {
                    Notification.requestPermission();
                  }
                } catch(_) {}
                initAudio();

                if (data.status === 'ready' && !isOrderAlarmDismissed()) {
                  startRepeatingAlarm();
                } else if (data.status === 'completed') {
                  showOrderCompletedModal();
                }
              } else {
                showSuccessModal({
                  title: 'Order Notice',
                  message: 'Order #' + urlInfo.order + ' was not found in cafe records. Returning to menu.',
                  buttonText: 'OK',
                  onDismiss: () => newOrder(true)
                });
              }
            })
            .catch(() => {
              _restorePendingCartIfAny();
            });
          return;
        }

        // ── SCENARIO 2: URL contains an explicit Table parameter (e.g. ?table=2, /table/2) ──
        if (urlInfo.table) {
          if (!isTableVerified || currentTable !== urlInfo.table || !currentTableToken) {
            showUnverifiedTableModal(urlInfo.table);
            _restorePendingCartIfAny();
            return;
          }
          const cleanUrlTable = urlInfo.table.toLowerCase().replace('table', '').trim();
          const cleanSavedTable = (savedTable || '').toLowerCase().replace('table', '').trim();
          const isDifferentTable = cleanSavedTable && cleanUrlTable !== cleanSavedTable;

          if (isDifferentTable) {
            // User changed the table in URL to a different table! Check if this new table has an active order:
            fetch('/api/table-order?table=' + encodeURIComponent(cleanUrlTable))
              .then(r => r.json())
              .then(data => {
                if (data && data.success && data.orderId && data.status &&
                    data.status !== 'completed' && data.status !== 'cancelled') {
                  const items = (data.items && Array.isArray(data.items)) ? data.items : [];
                  const total = (data.totalAmount !== undefined && data.totalAmount !== null) ? data.totalAmount : 0;
                  startOrderTracking(data.orderId, data.orderNumber, total, items, data.status);
                } else {
                  // New table has no active order -> reset old table tracking and show menu for new table!
                  newOrder(true);
                  currentTable = urlInfo.table;
                  try { _store.setItem('celestial_customer_table', currentTable); } catch(e) {}
                  updateOrderTypeHeaderPill();
                  _updateDiningModalUI();
                }
              })
              .catch(() => {
                newOrder(true);
                currentTable = urlInfo.table;
                try { _store.setItem('celestial_customer_table', currentTable); } catch(e) {}
                updateOrderTypeHeaderPill();
                _updateDiningModalUI();
              });
            return;
          }

          // Same table or no prior saved table: check active order on this table first
          fetch('/api/table-order?table=' + encodeURIComponent(cleanUrlTable))
            .then(r => r.json())
            .then(data => {
              if (data && data.success && data.orderId && data.status &&
                  data.status !== 'completed' && data.status !== 'cancelled') {
                const items = (data.items && Array.isArray(data.items)) ? data.items : [];
                const total = (data.totalAmount !== undefined && data.totalAmount !== null) ? data.totalAmount : 0;
                startOrderTracking(data.orderId, data.orderNumber, total, items, data.status);
              } else if (savedId || savedNum) {
                _verifySavedOrder(savedId, savedNum, savedTotal, savedItems);
              } else {
                _restorePendingCartIfAny();
              }
            })
            .catch(() => {
              if (savedId || savedNum) {
                _verifySavedOrder(savedId, savedNum, savedTotal, savedItems);
              } else {
                _restorePendingCartIfAny();
              }
            });
          return;
        }

        // ── SCENARIO 3: Generic URL without table or order param ──
        if (savedId || savedNum) {
          _verifySavedOrder(savedId, savedNum, savedTotal, savedItems);
          return;
        }

        _restorePendingCartIfAny();
      } catch(e) {}
    }

    window.addEventListener('popstate', () => {
      restoreActiveOrderIfAny();
    });

    // Restore a cart the customer built before accidentally refreshing/closing.
    function _restorePendingCartIfAny() {
      try {
        const raw = _store.getItem('pendingCart');
        if (raw) {
          const saved = JSON.parse(raw);
          if (Array.isArray(saved) && saved.length > 0) {
            cart = saved;
            updateCartBar();
          }
        }
      } catch(e) {}
      _checkFirstAppearDiningPrompt();
    }

    function _checkFirstAppearDiningPrompt() {
      if (activeTrackedOrderId) return;
      const trackerEl = document.getElementById('trackerView');
      if (trackerEl && trackerEl.style.display === 'block') return;

      const urlParams = new URLSearchParams(window.location.search);
      const urlOrderId = urlParams.get('id') || urlParams.get('orderId') || urlParams.get('order');
      if (urlOrderId) return;

      const chosen = sessionStorage.getItem('celestial_dining_chosen');
      if (!chosen) {
        setTimeout(showDiningOptionModal, 320);
      }
    }

    // Instant local render with inlined menu
    if (_tableAuth.hasTableAttempt && !_tableAuth.isVerified) {
      showUnverifiedTableModal(_tableAuth.tableNumber);
    } else {
      updateCategoryBar();
      renderMenu();
      connectCustomerWs();
      restoreActiveOrderIfAny();
      loadVoiceAudio();

      // Fallback: If inlined menu was empty or missing, fetch from /api/menu
      if (!menuData || menuData.length === 0) {
        fetch('/api/menu')
          .then(r => r.json())
          .then(data => {
            if (data && data.success && Array.isArray(data.menu) && data.menu.length > 0) {
              menuData = data.menu;
              updateCategoryBar();
              renderMenu();
            }
          })
          .catch(() => {});
      }
    }
  </script>
</body>
</html>
''';