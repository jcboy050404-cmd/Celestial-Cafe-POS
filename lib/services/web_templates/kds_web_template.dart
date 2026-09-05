// 1:1 Matched Fast Local KDS HTML Template
const String kdsHtmlTemplate = '''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <title>Celestial Cafe — Barista KDS</title>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Cinzel:wght@700;800;900&family=Outfit:wght@400;500;600;700;800;900&display=swap" rel="stylesheet">
  <style>
    :root {
      --bg-dark: #180e02ff;
      --bg-surface: #140E18;
      --bg-card: #1A1320;
      --gold-primary: #D4AF37;
      --gold-light: #F5D780;
      --brown-warm: #432C1D;
      --brown-dark: #1C120C;
      --emerald-ready: #2EC4B6;
      --amber-brewing: #FF9F1C;
      --rose-alert: #E71D36;
      --blue-info: #4CC9F0;
      --text-light: #F7EFE8;
      --text-muted: #AFA399;
      --text-subtle: #736962;
      --kds-zoom: 1;
    }
    * {
      box-sizing: border-box;
      margin: 0;
      padding: 0;
      font-family: 'Outfit', -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
      -webkit-tap-highlight-color: transparent;
    }
    body {
      background-color: var(--bg-dark);
      color: var(--text-light);
      min-height: 100vh;
      display: flex;
      flex-direction: column;
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
      padding: 10px 18px;
      display: flex;
      justify-content: space-between;
      align-items: center;
      position: sticky;
      top: 0;
      z-index: 100;
      flex-wrap: wrap;
      gap: 8px;
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
      padding: 6px 18px;
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
    @keyframes liquidShimmer {
      0% { background-position: 100% 0; }
      50% { background-position: 0% 0; }
      100% { background-position: 100% 0; }
    }
    .brand {
      display: flex;
      align-items: center;
      gap: 10px;
    }
    .brand-title {
      font-weight: 800;
      font-size: 15px;
      letter-spacing: 2px;
      color: #FFFFFF;
      line-height: 1.1;
    }
    .brand-sub {
      font-size: 9.5px;
      letter-spacing: 1px;
      font-weight: 600;
      color: var(--gold-light);
      opacity: 0.8;
      margin-top: 1px;
    }

    /* KDS Text Size & Display Zoom Controls */
    .kds-zoom-toolbar {
      display: inline-flex;
      align-items: center;
      background: var(--bg-card);
      border: 1.2px solid rgba(212, 175, 55, 0.3);
      border-radius: 20px;
      padding: 3px 8px;
      gap: 4px;
      box-shadow: 0 2px 8px rgba(0,0,0,0.3);
    }
    .zoom-btn {
      background: rgba(255, 255, 255, 0.06);
      border: 1px solid rgba(255, 255, 255, 0.15);
      color: var(--gold-light);
      border-radius: 8px;
      padding: 3px 7px;
      font-size: 11px;
      font-weight: 800;
      cursor: pointer;
      line-height: 1;
      transition: all 0.15s ease;
    }
    .zoom-btn:hover {
      background: var(--gold-primary);
      color: var(--bg-dark);
    }
    .zoom-btn:active {
      transform: scale(0.92);
    }
    .zoom-label {
      font-size: 11px;
      font-weight: 800;
      color: var(--gold-light);
      min-width: 36px;
      text-align: center;
    }
    .zoom-presets {
      display: flex;
      gap: 3px;
      margin-left: 2px;
    }
    .zoom-pill {
      background: transparent;
      border: 1px solid transparent;
      color: var(--text-muted);
      border-radius: 12px;
      padding: 2px 7px;
      font-size: 10px;
      font-weight: 600;
      cursor: pointer;
      transition: all 0.15s ease;
    }
    .zoom-pill.active {
      background: rgba(212, 175, 55, 0.25);
      border-color: var(--gold-primary);
      color: var(--gold-light);
      font-weight: 800;
    }
    .zoom-pill:hover {
      color: var(--text-light);
    }
    @media (max-width: 680px) {
      .zoom-presets { display: none; }
    }
    
    .status-badge {
      display: flex;
      align-items: center;
      gap: 6px;
      padding: 5px 12px;
      border-radius: 20px;
      font-size: 11px;
      font-weight: 700;
      background: rgba(46, 196, 182, 0.15);
      color: var(--emerald-ready);
      border: 1px solid rgba(46, 196, 182, 0.4);
    }
    .status-badge.disconnected {
      background: rgba(231, 29, 54, 0.15);
      color: var(--rose-alert);
      border-color: rgba(231, 29, 54, 0.4);
    }
    .dot {
      width: 7px;
      height: 7px;
      border-radius: 50%;
      background: currentColor;
      animation: pulse 2s infinite;
    }
    @keyframes pulse { 0% { opacity: 1; } 50% { opacity: 0.3; } 100% { opacity: 1; } }

    .filter-bar {
      background: var(--bg-surface);
      padding: 10px 16px;
      display: flex;
      gap: 8px;
      overflow-x: auto;
      border-bottom: 1px solid rgba(255, 255, 255, 0.06);
    }
    .tab-btn {
      background: var(--bg-card);
      border: 1px solid rgba(255, 255, 255, 0.08);
      color: var(--text-muted);
      padding: 7px 14px;
      border-radius: 20px;
      font-size: 12px;
      font-weight: 600;
      cursor: pointer;
      white-space: nowrap;
      display: flex;
      align-items: center;
      gap: 6px;
      transition: all 0.15s ease;
    }
    .tab-btn.active {
      background: rgba(212, 175, 55, 0.2);
      border-color: var(--gold-primary);
      color: var(--text-light);
      font-weight: 700;
    }
    .tab-count {
      padding: 1px 6px;
      border-radius: 10px;
      font-size: 10px;
      font-weight: 800;
      background: rgba(255, 255, 255, 0.1);
    }
    .tab-btn.active .tab-count {
      background: var(--gold-primary);
      color: var(--bg-dark);
    }

    main {
      flex: 1;
      padding: 16px;
      display: grid;
      grid-template-columns: repeat(auto-fill, minmax(310px, 1fr));
      gap: 16px;
      align-content: start;
    }

    .ticket {
      background: linear-gradient(170deg, #1C1522 0%, #120D17 100%);
      border-radius: 20px;
      border: 1.5px solid rgba(255, 255, 255, 0.08);
      overflow: hidden;
      display: flex;
      flex-direction: column;
      box-shadow: 0 10px 30px rgba(0, 0, 0, 0.6);
      transition: all 0.2s cubic-bezier(0.2, 0.8, 0.4, 1);
    }
    .ticket:hover {
      border-color: rgba(255, 255, 255, 0.16);
      transform: translateY(-2px);
      box-shadow: 0 14px 38px rgba(0, 0, 0, 0.7);
    }
    .ticket.pending {
      border-color: rgba(212, 175, 55, 0.38);
      box-shadow: 0 10px 30px rgba(0, 0, 0, 0.6), 0 0 15px rgba(212, 175, 55, 0.08);
    }
    .ticket.preparing {
      border-color: rgba(255, 159, 28, 0.65);
      box-shadow: 0 10px 32px rgba(255, 159, 28, 0.2), 0 0 18px rgba(255, 159, 28, 0.1);
    }
    .ticket.ready {
      border-color: rgba(46, 196, 182, 0.65);
      box-shadow: 0 10px 32px rgba(46, 196, 182, 0.2), 0 0 18px rgba(46, 196, 182, 0.1);
    }

    .ticket-header {
      padding: 14px 16px 11px 16px;
      background: rgba(46, 29, 21, 0.45);
      border-bottom: 1px solid rgba(255, 255, 255, 0.07);
      display: flex;
      justify-content: space-between;
      align-items: center;
    }
    .ticket-title-group { display: flex; align-items: center; gap: 9px; }
    .ticket-number {
      font-family: 'Cinzel', 'Outfit', serif;
      font-size: 20px;
      font-weight: 900;
      color: var(--gold-light);
      letter-spacing: 0.8px;
      text-shadow: 0 2px 8px rgba(212, 175, 55, 0.25);
    }
    .order-type-badge {
      padding: 3px 9px;
      border-radius: 8px;
      font-size: 11px;
      font-weight: 800;
      background: rgba(67, 44, 29, 0.45);
      color: var(--gold-light);
      border: 1px solid rgba(212, 175, 55, 0.3);
      display: inline-flex;
      align-items: center;
      gap: 4px;
    }
    .order-type-badge.takeout-badge {
      background: linear-gradient(135deg, #FF9F1C 0%, #E07A00 100%) !important;
      color: #000000 !important;
      font-weight: 900 !important;
      border: 1px solid #FFA000 !important;
      box-shadow: 0 2px 8px rgba(0, 0, 0, 0.4);
    }
    .ticket.takeout-ticket {
      border-left: 5px solid #FF9F1C !important;
    }
    .takeout-banner {
      background: rgba(255, 159, 28, 0.16);
      border: 1.2px solid rgba(255, 159, 28, 0.55);
      color: #FFB74D;
      font-size: 11px;
      font-weight: 900;
      letter-spacing: 0.5px;
      padding: 6px 12px;
      border-radius: 8px;
      margin: 8px 16px 2px 16px;
      display: flex;
      align-items: center;
      gap: 6px;
    }
    .takeout-item-badge {
      background: rgba(255, 159, 28, 0.24);
      border: 1px solid rgba(255, 159, 28, 0.65);
      color: #FFB74D;
      font-size: 10px;
      font-weight: 900;
      padding: 1px 6px;
      border-radius: 4px;
      margin-left: 6px;
      display: inline-flex;
      align-items: center;
      gap: 3px;
    }

    .ticket-header-right { display: flex; align-items: center; gap: 6px; }
    .timer-badge { display: flex; align-items: center; gap: 4px; padding: 4px 8px; border-radius: 8px; font-size: 11px; font-weight: 700; }
    .timer-green { background: rgba(46, 196, 182, 0.15); border: 1px solid rgba(46, 196, 182, 0.5); color: var(--emerald-ready); }
    .timer-amber { background: rgba(255, 159, 28, 0.15); border: 1px solid rgba(255, 159, 28, 0.5); color: var(--amber-brewing); }
    .timer-red { background: rgba(231, 29, 54, 0.15); border: 1px solid rgba(231, 29, 54, 0.5); color: var(--rose-alert); }

    .void-btn {
      background: rgba(231, 29, 54, 0.15);
      border: 1px solid rgba(231, 29, 54, 0.4);
      color: var(--rose-alert);
      border-radius: 6px;
      width: 26px;
      height: 26px;
      font-size: 13px;
      font-weight: bold;
      cursor: pointer;
      display: flex;
      align-items: center;
      justify-content: center;
      transition: background 0.15s;
    }
    .void-btn:active { background: var(--rose-alert); color: #fff; }

    .ticket-sub {
      padding: 8px 16px;
      display: flex;
      justify-content: space-between;
      align-items: center;
      border-bottom: 1px solid rgba(255, 255, 255, 0.05);
      font-size: 12px;
    }
    .guest-name { font-weight: 600; color: var(--text-light); }
    .item-count-text { color: var(--text-muted); font-size: 11px; }

    .ticket-body { padding: 14px 16px; flex: 1; }
    
    .item-row {
      margin-bottom: 10px;
      padding: 6px 8px;
      border-radius: 8px;
      border-bottom: 1px dashed rgba(255, 255, 255, 0.07);
      cursor: pointer;
      user-select: none;
      transition: all 0.18s ease;
      position: relative;
    }
    .item-row:hover {
      background: rgba(255, 255, 255, 0.035);
    }
    .item-row:active {
      transform: scale(0.99);
    }
    .item-row:last-child { margin-bottom: 0; padding-bottom: 4px; border-bottom: none; }
    
    .item-row.item-done {
      opacity: 0.52;
      background: rgba(46, 196, 182, 0.06);
      border: 1px solid rgba(46, 196, 182, 0.25);
    }
    .item-row.item-done .item-name {
      text-decoration: line-through;
      color: #A39B94;
    }
    .item-row.item-done .custom-list {
      opacity: 0.45;
      text-decoration: line-through;
    }
    .item-row.item-done .note-box {
      text-decoration: line-through;
      opacity: 0.5;
      background: rgba(255, 255, 255, 0.04);
      border-color: rgba(255, 255, 255, 0.1);
      color: var(--text-muted);
    }
    .item-row.item-done .item-qty {
      background: rgba(46, 196, 182, 0.35);
      color: #2EC4B6;
    }
    .item-row.item-row-locked {
      cursor: default;
    }
    .item-row.item-row-locked:hover {
      background: transparent;
    }
    .item-row.item-row-locked .item-prep-toggle {
      border-color: rgba(255, 255, 255, 0.12);
      opacity: 0.55;
    }

    .item-prep-toggle {
      width: 18px;
      height: 18px;
      border-radius: 5px;
      border: 1.5px solid rgba(255, 255, 255, 0.28);
      background: rgba(255, 255, 255, 0.04);
      display: inline-flex;
      align-items: center;
      justify-content: center;
      color: transparent;
      font-size: 11px;
      font-weight: 900;
      margin-right: 2px;
      flex-shrink: 0;
      transition: all 0.15s ease;
    }
    .item-row.item-done .item-prep-toggle {
      background: #2EC4B6;
      border-color: #2EC4B6;
      color: #0D0B10;
      box-shadow: none;
    }
    .item-prepared-badge {
      display: inline-flex;
      align-items: center;
      gap: 3px;
      font-size: 9.5px;
      font-weight: 900;
      color: #2EC4B6;
      background: rgba(46, 196, 182, 0.16);
      border: 1px solid rgba(46, 196, 182, 0.45);
      padding: 1.5px 6px;
      border-radius: 8px;
      letter-spacing: 0.4px;
      margin-left: auto;
    }
    .note-box {
      margin-top: 5px;
      margin-left: 28px;
      padding: 4px 8px;
      background: rgba(231, 29, 54, 0.12);
      border: 1px solid rgba(231, 29, 54, 0.35);
      border-radius: 6px;
      font-size: 11px;
      font-weight: 700;
      color: #FF6B6B;
      display: inline-flex;
      align-items: center;
      gap: 5px;
    }
    .all-prepared-banner {
      margin: 8px 14px 2px 14px;
      padding: 6px 10px;
      background: rgba(46, 196, 182, 0.14);
      border: 1.2px solid rgba(46, 196, 182, 0.45);
      border-radius: 8px;
      color: #2EC4B6;
      font-size: 11.5px;
      font-weight: 800;
      text-align: center;
      letter-spacing: 0.3px;
    }
    
    .item-title-row { display: flex; align-items: center; gap: calc(8px * var(--kds-zoom, 1)); flex-wrap: wrap; }
    .item-qty {
      padding: calc(2px * var(--kds-zoom, 1)) calc(6px * var(--kds-zoom, 1));
      border-radius: 6px;
      background: var(--gold-primary);
      color: var(--bg-dark);
      font-size: calc(12px * var(--kds-zoom, 1));
      font-weight: 800;
      min-width: calc(24px * var(--kds-zoom, 1));
      text-align: center;
    }
    .item-name { font-weight: 700; font-size: calc(14px * var(--kds-zoom, 1)); color: var(--text-light); flex: 1; }

    /* Kitchen Cook Dish Highlighting */
    .ticket.has-kitchen {
      border-top: 3.5px solid #FF5722 !important;
      box-shadow: 0 4px 20px rgba(255, 87, 34, 0.16) !important;
    }
    .kitchen-item-row {
      background: linear-gradient(135deg, rgba(255, 87, 34, 0.16) 0%, rgba(255, 112, 67, 0.05) 100%) !important;
      border: 1.5px solid rgba(255, 87, 34, 0.5) !important;
      border-left: 4px solid #FF5722 !important;
      border-radius: 10px;
      padding: 9px 11px !important;
      margin-bottom: 9px !important;
      box-shadow: 0 2px 10px rgba(255, 87, 34, 0.15);
    }
    .kitchen-tag {
      display: inline-flex;
      align-items: center;
      gap: 4px;
      font-size: calc(10px * var(--kds-zoom, 1));
      font-weight: 900;
      letter-spacing: 0.8px;
      text-transform: uppercase;
      color: #FF7043;
      background: rgba(255, 87, 34, 0.22);
      border: 1px solid rgba(255, 87, 34, 0.45);
      border-radius: 5px;
      padding: 2px 7px;
      margin-bottom: 5px;
    }
    .kitchen-name {
      color: #FFE0B2 !important;
      font-size: calc(15px * var(--kds-zoom, 1)) !important;
      font-weight: 800 !important;
    }
    .kitchen-qty {
      background: #FF5722 !important;
      color: #FFFFFF !important;
      box-shadow: 0 2px 8px rgba(255, 87, 34, 0.4);
    }
    .custom-item {
      font-size: calc(11.5px * var(--kds-zoom, 1));
      color: var(--text-muted);
      margin-bottom: 2px;
    }
    .note-box {
      font-size: calc(11.5px * var(--kds-zoom, 1));
    }
    .station-badge-kitchen {
      background: rgba(255, 87, 34, 0.2);
      border: 1.2px solid rgba(255, 87, 34, 0.65);
      color: #FF7043;
      padding: 2px 8px;
      border-radius: 12px;
      font-size: 10.5px;
      font-weight: 800;
      display: inline-flex;
      align-items: center;
      gap: 4px;
    }
    .station-badge-bar {
      background: rgba(255, 159, 28, 0.16);
      border: 1.2px solid rgba(255, 159, 28, 0.5);
      color: var(--gold-light);
      padding: 2px 8px;
      border-radius: 12px;
      font-size: 10.5px;
      font-weight: 800;
      display: inline-flex;
      align-items: center;
      gap: 4px;
    }

    .size-badge { font-size: 11px; font-weight: 800; padding: 3px 8px; border-radius: 6px; letter-spacing: 0.5px; }
    .size-16oz { background: rgba(76, 201, 240, 0.25); color: var(--blue-info); border: 1.2px solid var(--blue-info); }
    .size-22oz { background: rgba(255, 159, 28, 0.25); color: var(--amber-brewing); border: 1.2px solid var(--amber-brewing); }

    .custom-list { margin-top: 4px; padding-left: 32px; font-size: 11.5px; font-weight: 500; color: var(--gold-light); }
    .custom-item { margin-top: 2px; }

    .order-memo-box {
      margin: 8px 16px 0 16px;
      padding: 8px 10px;
      background: rgba(255, 159, 28, 0.1);
      border: 1px solid rgba(255, 159, 28, 0.3);
      border-radius: 8px;
      font-size: 11px;
      color: var(--amber-brewing);
      display: flex;
      align-items: center;
      gap: 6px;
    }

    .ticket-footer {
      padding: 12px 14px;
      background: var(--bg-surface);
      border-top: 1px solid rgba(255, 255, 255, 0.05);
      display: flex;
      gap: 8px;
    }
    .action-btn {
      width: 100%;
      padding: 12px 10px;
      border-radius: 12px;
      border: none;
      font-size: 13px;
      font-weight: 800;
      cursor: pointer;
      display: flex;
      align-items: center;
      justify-content: center;
      gap: 8px;
      transition: all 0.16s cubic-bezier(0.2, 0.8, 0.4, 1);
      letter-spacing: 0.3px;
    }
    .action-btn:hover {
      transform: translateY(-1.5px);
      filter: brightness(1.08);
    }
    .action-btn:active {
      transform: scale(0.96) translateY(1px);
      filter: brightness(0.95);
    }
    .btn-brew {
      background: linear-gradient(135deg, #FF9F1C 0%, #D87700 100%);
      color: #0B080D;
      box-shadow: 0 4px 16px rgba(255, 159, 28, 0.4);
    }
    .btn-ready {
      background: linear-gradient(135deg, #2EC4B6 0%, #178B81 100%);
      color: #0B080D;
      box-shadow: 0 4px 16px rgba(46, 196, 182, 0.4);
    }
    .btn-done {
      background: linear-gradient(135deg, #22C55E 0%, #15803D 100%);
      color: #FFFFFF;
      font-weight: 800;
      box-shadow: 0 4px 16px rgba(34, 197, 94, 0.45);
    }

    .btn-spinner {
      display: inline-block;
      width: 14px;
      height: 14px;
      border: 2px solid rgba(0, 0, 0, 0.25);
      border-top-color: currentColor;
      border-radius: 50%;
      animation: spin 0.6s linear infinite;
    }
    .btn-done .btn-spinner {
      border: 2px solid rgba(255, 255, 255, 0.35);
      border-top-color: #ffffff;
    }
    @keyframes spin {
      to { transform: rotate(360deg); }
    }

    /* Live Barista Order Action & Checklist Confirmation Modal (Matched 1:1 to KDS) */
    .kds-modal-overlay {
      position: fixed;
      top: 0;
      left: 0;
      right: 0;
      bottom: 0;
      background: rgba(0, 0, 0, 0.8);
      backdrop-filter: blur(8px);
      -webkit-backdrop-filter: blur(8px);
      z-index: 99999;
      display: none;
      align-items: center;
      justify-content: center;
      padding: 16px;
      overflow-y: auto;
    }
    .kds-confirm-card {
      max-width: 440px;
      width: 100%;
      background: var(--bg-surface);
      border: 1.5px solid rgba(46, 196, 182, 0.5);
      border-radius: 18px;
      padding: 22px 20px 20px 20px;
      text-align: left;
      box-shadow: 0 16px 50px rgba(0, 0, 0, 0.9), 0 0 24px rgba(0, 0, 0, 0.6);
      margin: auto;
      animation: kdsModalPop 0.22s cubic-bezier(0.16, 1, 0.3, 1);
      box-sizing: border-box;
    }
    @keyframes kdsModalPop {
      0% { opacity: 0; transform: scale(0.92) translateY(8px); }
      100% { opacity: 1; transform: scale(1) translateY(0); }
    }
    .kds-chk-item {
      display: flex;
      align-items: flex-start;
      gap: 10px;
      padding: 6px 6px;
      border-radius: 8px;
      cursor: pointer;
      user-select: none;
      transition: background 0.15s ease;
    }
    .kds-chk-item:hover {
      background: rgba(255, 255, 255, 0.04);
    }
    .kds-chk-box {
      width: 17px;
      height: 17px;
      min-width: 17px;
      border: 1.8px solid var(--gold-primary);
      border-radius: 4px;
      margin-top: 2px;
      display: inline-flex;
      align-items: center;
      justify-content: center;
      transition: all 0.15s ease;
      box-sizing: border-box;
      background: transparent;
    }
    .kds-chk-box.checked {
      background: var(--gold-primary);
      border-color: var(--gold-primary);
    }
    .kds-chk-box svg {
      display: none;
      width: 11px;
      height: 11px;
    }
    .kds-chk-box.checked svg {
      display: block;
    }
    .kds-chk-card-scroll::-webkit-scrollbar {
      width: 5px;
    }
    .kds-chk-card-scroll::-webkit-scrollbar-track {
      background: rgba(0, 0, 0, 0.15);
      border-radius: 4px;
    }
    .kds-chk-card-scroll::-webkit-scrollbar-thumb {
      background: rgba(212, 175, 55, 0.35);
      border-radius: 4px;
    }
    .kds-chk-card-scroll::-webkit-scrollbar-thumb:hover {
      background: rgba(212, 175, 55, 0.6);
    }

    .pin-modal-overlay {
      position: fixed;
      top: 0;
      left: 0;
      right: 0;
      bottom: 0;
      background: radial-gradient(circle at 50% 32%, rgba(38, 26, 48, 0.94) 0%, rgba(9, 6, 12, 0.98) 100%);
      backdrop-filter: blur(14px);
      -webkit-backdrop-filter: blur(14px);
      z-index: 99999;
      display: flex;
      align-items: center;
      justify-content: center;
      padding: 20px;
      animation: pinFadeIn 0.25s ease-out;
    }
    @keyframes pinFadeIn {
      from { opacity: 0; }
      to { opacity: 1; }
    }
    .pin-card {
      position: relative;
      background: linear-gradient(170deg, rgba(30, 22, 36, 0.96) 0%, rgba(14, 10, 18, 0.98) 100%);
      border: 1.5px solid rgba(212, 175, 55, 0.45);
      border-radius: 28px;
      padding: 32px 28px 26px 28px;
      max-width: 375px;
      width: 100%;
      text-align: center;
      box-shadow: 0 24px 70px rgba(0, 0, 0, 0.9), 0 0 45px rgba(212, 175, 55, 0.18);
      overflow: hidden;
      animation: pinPopCard 0.32s cubic-bezier(0.16, 1, 0.3, 1);
    }
    .pin-card::before {
      content: '';
      position: absolute;
      top: 0;
      left: 15%;
      right: 15%;
      height: 2px;
      background: linear-gradient(90deg, transparent, var(--gold-primary), transparent);
    }
    @keyframes pinPopCard {
      0% { opacity: 0; transform: scale(0.9) translateY(16px); }
      100% { opacity: 1; transform: scale(1) translateY(0); }
    }
    .pin-logo-box {
      margin-bottom: 14px;
      display: flex;
      justify-content: center;
    }
    .pin-logo-frame {
      width: 60px;
      height: 60px;
      border-radius: 50%;
      background: linear-gradient(135deg, rgba(212, 175, 55, 0.22) 0%, rgba(67, 44, 29, 0.4) 100%);
      border: 1.5px solid rgba(212, 175, 55, 0.55);
      box-shadow: 0 4px 20px rgba(212, 175, 55, 0.35);
      display: flex;
      align-items: center;
      justify-content: center;
    }
    .pin-title {
      font-family: 'Outfit', sans-serif;
      font-weight: 900;
      font-size: 17px;
      letter-spacing: 1.8px;
      color: var(--gold-light);
      margin-bottom: 3px;
      text-shadow: 0 2px 10px rgba(212, 175, 55, 0.3);
    }
    .pin-sub {
      display: inline-flex;
      align-items: center;
      gap: 5px;
      background: rgba(255, 159, 28, 0.16);
      border: 1px solid rgba(255, 159, 28, 0.45);
      color: var(--amber-brewing);
      font-size: 10px;
      font-weight: 800;
      letter-spacing: 1px;
      text-transform: uppercase;
      padding: 3px 10px;
      border-radius: 20px;
      margin: 6px 0 10px 0;
    }
    .pin-desc {
      font-size: 12.5px;
      color: var(--text-muted);
      margin-bottom: 18px;
      line-height: 1.45;
    }
    .pin-dots-container {
      display: flex;
      justify-content: center;
      gap: 16px;
      margin-bottom: 16px;
      padding: 6px 0;
    }
    .pin-dot {
      width: 18px;
      height: 18px;
      border-radius: 50%;
      border: 2px solid rgba(212, 175, 55, 0.4);
      background: rgba(255, 255, 255, 0.04);
      box-shadow: inset 0 2px 4px rgba(0, 0, 0, 0.6);
      transition: all 0.22s cubic-bezier(0.34, 1.56, 0.64, 1);
    }
    .pin-dot.filled {
      background: linear-gradient(135deg, #FFF0B3 0%, var(--gold-primary) 50%, #B89025 100%);
      border-color: #FFF0B3;
      transform: scale(1.15);
    }
    .pin-dots-container.shake {
      animation: shakeDots 0.45s ease;
    }
    @keyframes shakeDots {
      0%, 100% { transform: translateX(0); }
      15%, 45%, 75% { transform: translateX(-9px); }
      30%, 60%, 90% { transform: translateX(9px); }
    }
    .pin-error-msg {
      font-size: 12px;
      color: var(--rose-alert);
      font-weight: 800;
      min-height: 20px;
      margin-bottom: 14px;
      letter-spacing: 0.3px;
    }
    .pin-keypad {
      display: grid;
      grid-template-columns: repeat(3, 1fr);
      gap: 11px;
      max-width: 290px;
      margin: 0 auto;
    }
    .pin-key {
      background: linear-gradient(165deg, rgba(255, 255, 255, 0.07) 0%, rgba(255, 255, 255, 0.02) 100%);
      border: 1.2px solid rgba(255, 255, 255, 0.12);
      border-radius: 16px;
      height: 54px;
      color: var(--text-light);
      font-size: 21px;
      font-weight: 800;
      cursor: pointer;
      display: flex;
      align-items: center;
      justify-content: center;
      transition: all 0.16s cubic-bezier(0.2, 0.8, 0.4, 1);
      user-select: none;
      box-shadow: 0 4px 12px rgba(0, 0, 0, 0.35);
    }
    .pin-key:hover {
      background: linear-gradient(165deg, rgba(212, 175, 55, 0.25) 0%, rgba(212, 175, 55, 0.08) 100%);
      border-color: rgba(212, 175, 55, 0.6);
      color: var(--gold-light);
      box-shadow: 0 6px 18px rgba(212, 175, 55, 0.25);
      transform: translateY(-1.5px);
    }
    .pin-key:active {
      transform: scale(0.92) translateY(1px);
      background: rgba(212, 175, 55, 0.35);
      box-shadow: 0 2px 6px rgba(0, 0, 0, 0.5);
    }
    .pin-key-clear {
      font-size: 15px;
      font-weight: 800;
      color: var(--amber-brewing);
      background: rgba(255, 159, 28, 0.1);
      border-color: rgba(255, 159, 28, 0.3);
    }
    .pin-key-clear:hover {
      background: rgba(255, 159, 28, 0.25);
      border-color: rgba(255, 159, 28, 0.5);
      color: #FFB74D;
    }
    .pin-key-backspace {
      font-size: 17px;
      color: #FF6B6B;
      background: rgba(231, 29, 54, 0.1);
      border-color: rgba(231, 29, 54, 0.3);
    }
    .pin-key-backspace:hover {
      background: rgba(231, 29, 54, 0.25);
      border-color: rgba(231, 29, 54, 0.5);
      color: #FF8787;
    }

    .empty-state { grid-column: 1 / -1; text-align: center; padding: 60px 20px; color: var(--text-muted); }
    .empty-icon { font-size: 48px; margin-bottom: 12px; }
  </style>
</head>
<body>
  <header>
    <div class="brand">
      <img src="/logo.png" style="height: 38px; width: 38px; border-radius: 50%; object-fit: cover; border: 1.5px solid rgba(212, 175, 55, 0.4); box-shadow: 0 2px 8px rgba(212,175,55,0.25);" alt="Logo" onerror="this.style.display='none'">
      <div>
        <div class="brand-title">CELESTIAL CAFE</div>
        <div class="brand-sub">KITCHEN DISPLAY SYSTEM (KDS)</div>
      </div>
    </div>
    <div style="display: flex; align-items: center; gap: 10px; flex-wrap: wrap;">
      <!-- Zoom & Text Size Toolbar for Baristas & Kitchen -->
      <div class="kds-zoom-toolbar" title="Barista Text Size / Zoom Scaling">
        <span style="font-size: 11px; color: var(--gold-light); font-weight: 700; margin-right: 2px;">👁️ Zoom:</span>
        <button type="button" class="zoom-btn" onclick="adjustKdsZoom(-0.15)" title="Decrease Text Size">A−</button>
        <span id="kdsZoomLabel" class="zoom-label">100%</span>
        <button type="button" class="zoom-btn" onclick="adjustKdsZoom(0.15)" title="Increase Text Size (Vision Aid)">A+</button>
        <div class="zoom-presets">
          <button type="button" class="zoom-pill active" data-zoom="1.0" onclick="setKdsZoom(1.0)">100%</button>
          <button type="button" class="zoom-pill" data-zoom="1.2" onclick="setKdsZoom(1.2)">120%</button>
          <button type="button" class="zoom-pill" data-zoom="1.4" onclick="setKdsZoom(1.4)">140%</button>
          <button type="button" class="zoom-pill" data-zoom="1.65" onclick="setKdsZoom(1.65)">165% (Huge)</button>
        </div>
      </div>

      <div id="statusBadge" class="status-badge">
        <div class="dot"></div>
        <span id="statusText">Live Sync</span>
      </div>
    </div>
  </header>

  <!-- Barista Security PIN Unlock Screen -->
  <div id="pinModal" class="pin-modal-overlay" style="display: none;">
    <div class="pin-card">
      <div class="pin-logo-box">
        <div class="pin-logo-frame">
          <img src="/logo.png" style="height: 42px; width: 42px; border-radius: 50%; object-fit: cover;" alt="Logo" onerror="this.style.display='none'">
        </div>
      </div>
      <div class="pin-title">BARISTA & KITCHEN CONSOLE</div>
      <div class="pin-sub">
        <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="11" width="18" height="11" rx="2" ry="2"></rect><path d="M7 11V7a5 5 0 0 1 10 0v4"></path></svg>
        <span>Security PIN Required</span>
      </div>
      <div class="pin-desc">Enter 4-digit security PIN to unlock the live kitchen display.</div>

      <div class="pin-dots-container" id="pinDots">
        <div class="pin-dot"></div>
        <div class="pin-dot"></div>
        <div class="pin-dot"></div>
        <div class="pin-dot"></div>
      </div>

      <div id="pinError" class="pin-error-msg"></div>

      <div class="pin-keypad">
        <button type="button" class="pin-key" onclick="handlePinKey('1')">1</button>
        <button type="button" class="pin-key" onclick="handlePinKey('2')">2</button>
        <button type="button" class="pin-key" onclick="handlePinKey('3')">3</button>
        <button type="button" class="pin-key" onclick="handlePinKey('4')">4</button>
        <button type="button" class="pin-key" onclick="handlePinKey('5')">5</button>
        <button type="button" class="pin-key" onclick="handlePinKey('6')">6</button>
        <button type="button" class="pin-key" onclick="handlePinKey('7')">7</button>
        <button type="button" class="pin-key" onclick="handlePinKey('8')">8</button>
        <button type="button" class="pin-key" onclick="handlePinKey('9')">9</button>
        <button type="button" class="pin-key pin-key-clear" onclick="handlePinClear()">C</button>
        <button type="button" class="pin-key" onclick="handlePinKey('0')">0</button>
        <button type="button" class="pin-key pin-key-backspace" onclick="handlePinBackspace()">⌫</button>
      </div>

      <div style="margin-top: 18px; font-size: 11px; color: var(--text-subtle); display: flex; align-items: center; justify-content: center; gap: 5px;">
        <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="3" y="11" width="18" height="11" rx="2" ry="2"></rect><path d="M7 11V7a5 5 0 0 1 10 0v4"></path></svg>
        <span>Security protected • Check POS Hotspot Dialog for PIN</span>
      </div>
    </div>
  </div>

  <!-- Barista Action Confirmation Modal (Matched 1:1 to KDS Order Checklist) -->
  <div class="kds-modal-overlay" id="kdsConfirmModal" onclick="if(event.target===this) closeKdsConfirmModal()">
    <div class="kds-confirm-card" id="kdsConfirmCard">
      
      <!-- Top Title Header -->
      <div style="display: flex; align-items: center; gap: 12px;">
        <div id="kdsConfirmIconBox" style="width: 44px; height: 44px; min-width: 44px; border-radius: 12px; background: rgba(46,196,182,0.15); border: 1.2px solid rgba(46,196,182,0.4); display: flex; align-items: center; justify-content: center; flex-shrink: 0;">
          <!-- SVG Icon inserted dynamically -->
        </div>
        <div style="flex: 1; min-width: 0;">
          <div id="kdsConfirmTitle" style="font-size: 16.5px; font-weight: 800; color: #FFFFFF; letter-spacing: -0.2px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis;">
            Mark Ready for Pickup • #11
          </div>
          <div id="kdsConfirmSubtitle" style="font-size: 12px; color: var(--text-muted); font-weight: 600; margin-top: 2px;">
            Dine-In • Table 1
          </div>
        </div>
      </div>

      <!-- Warning / Double-Check Notice Banner -->
      <div id="kdsConfirmNotice" style="margin-top: 15px; padding: 11px 13px; background: rgba(212, 175, 55, 0.12); border: 1px solid rgba(212, 175, 55, 0.35); border-radius: 10px; display: flex; align-items: flex-start; gap: 10px;">
        <div style="color: var(--gold-light); display: flex; align-items: center; margin-top: 1px; flex-shrink: 0;">
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round">
            <path d="M3 7l3 3 5-5"></path>
            <path d="M14 6h7"></path>
            <path d="M3 17l3 3 5-5"></path>
            <path d="M14 16h7"></path>
          </svg>
        </div>
        <div id="kdsConfirmNoticeText" style="font-size: 12px; font-weight: 700; color: var(--gold-light); line-height: 1.38; flex: 1;">
          Kindly double check if the item is correct and complete before proceeding.
        </div>
      </div>

      <!-- Order Items Checklist Summary Label -->
      <div id="kdsConfirmChecklistLabel" style="margin-top: 15px; margin-bottom: 8px; font-size: 12px; font-weight: 700; color: var(--text-muted); letter-spacing: 0.3px;">
        Order Items Checklist (2 pcs):
      </div>

      <!-- Checklist Items Card -->
      <div class="kds-chk-card-scroll" id="kdsConfirmChecklistCard" style="background: var(--bg-card); border: 1px solid rgba(255, 255, 255, 0.08); border-radius: 12px; padding: 12px 14px; max-height: 230px; overflow-y: auto;">
        <!-- Checklist items rendered dynamically -->
      </div>

      <!-- Actions (Cancel / Review, Confirm) -->
      <div style="margin-top: 18px; display: flex; align-items: center; justify-content: flex-end; gap: 10px;">
        <button type="button" onclick="closeKdsConfirmModal()" style="background: transparent; border: none; color: var(--text-muted); font-size: 13px; font-weight: 700; padding: 10px 14px; border-radius: 8px; cursor: pointer; transition: color 0.15s ease;" onmouseover="this.style.color='#FFFFFF'" onmouseout="this.style.color='var(--text-muted)'">
          Cancel / Review
        </button>
        <button type="button" id="btnKdsConfirmAction" style="background: var(--emerald-ready); border: none; color: #0D0B10; border-radius: 10px; padding: 11px 18px; font-weight: 800; font-size: 13px; cursor: pointer; display: inline-flex; align-items: center; gap: 8px; box-shadow: 0 4px 14px rgba(46,196,182,0.35); transition: transform 0.1s ease, filter 0.15s ease;">
          <span id="kdsConfirmActionIcon" style="display: inline-flex; align-items: center;"></span>
          <span id="kdsConfirmActionText">Confirm Ready</span>
        </button>
      </div>

    </div>
  </div>

  <div class="filter-bar">
    <button class="tab-btn active" onclick="setFilter('all', this)">Active Queue <span class="tab-count" id="countAll">0</span></button>
    <button class="tab-btn" onclick="setFilter('confirmed', this)">Confirmed <span class="tab-count" id="countQueue">0</span></button>
    <button class="tab-btn" onclick="setFilter('preparing', this)">Brewing / Prep <span class="tab-count" id="countBrewing">0</span></button>
    <button class="tab-btn" onclick="setFilter('ready', this)">Ready for Pickup <span class="tab-count" id="countReady">0</span></button>
    <button class="tab-btn" onclick="setFilter('kitchen', this)" style="border: 1px solid rgba(255,87,34,0.5); color: #FF7043;">Kitchen Food <span class="tab-count" id="countKitchen" style="background: rgba(255,87,34,0.25); color: #FF7043;">0</span></button>
    <button class="tab-btn" onclick="setFilter('barista', this)" style="border: 1px solid rgba(255,159,28,0.4); color: var(--gold-light);">Barista Drinks <span class="tab-count" id="countBarista">0</span></button>
    <button class="tab-btn" onclick="setFilter('takeout', this)" style="border: 1px solid #FF9F1C; color: #FFB74D; font-weight: 800;">🥡 Takeout <span class="tab-count" id="countTakeout" style="background: rgba(255,159,28,0.3); color: #FFB74D;">0</span></button>
  </div>

  <main id="ticketsContainer">
    <div class="empty-state">
      <div class="empty-icon" style="font-size:36px;opacity:0.3;">—</div>
      <h3>No Active Kitchen Tickets</h3>
      <p style="font-size: 13px; margin-top: 4px;">Orders approved & confirmed at the POS will appear here live.</p>
    </div>
  </main>

  <script>
    let authPin = sessionStorage.getItem('celestial_barista_pin') || localStorage.getItem('celestial_barista_pin') || '';
    let isAuthorized = false;
    let currentOrders = [];
    let enteredDigits = '';
    let ws;
    let audioContext;
    let activeFilter = 'all';
    let preparedItemKeys = new Set();
    try {
      const savedPrep = JSON.parse(sessionStorage.getItem('celestial_kds_prepared_items') || '[]');
      if (Array.isArray(savedPrep)) preparedItemKeys = new Set(savedPrep);
    } catch(e) {}

    // Instant local cache restore (0.00s instant ticket render on open/refresh)
    try {
      const cached = localStorage.getItem('celestial_kds_orders_cache');
      if (cached) {
        currentOrders = JSON.parse(cached);
        if (Array.isArray(currentOrders) && currentOrders.length > 0) {
          renderOrders(currentOrders);
        }
      }
    } catch(e) {}

    // Dynamic Liquid Glass Header Scroll Listener
    const initKdsHeaderScroll = () => {
      const hdr = document.querySelector('header');
      if (!hdr) return;
      let ticking = false;
      window.addEventListener('scroll', () => {
        if (!ticking) {
          window.requestAnimationFrame(() => {
            if (window.scrollY > 8) {
              hdr.classList.add('scrolled');
            } else {
              hdr.classList.remove('scrolled');
            }
            ticking = false;
          });
          ticking = true;
        }
      }, { passive: true });
      if (window.scrollY > 8) hdr.classList.add('scrolled');
    };
    initKdsHeaderScroll();

    function updatePinDots() {
      const dots = document.querySelectorAll('.pin-dot');
      dots.forEach((d, i) => {
        if (i < enteredDigits.length) {
          d.classList.add('filled');
        } else {
          d.classList.remove('filled');
        }
      });
    }

    function playAudioClick(freq, duration) {
      try {
        if (!audioContext) audioContext = new (window.AudioContext || window.webkitAudioContext)();
        if (audioContext.state === 'suspended') audioContext.resume();
        const f = freq || 700;
        const d = duration || 0.035;
        const osc = audioContext.createOscillator();
        const gain = audioContext.createGain();
        osc.type = 'sine';
        osc.frequency.setValueAtTime(f, audioContext.currentTime);
        gain.gain.setValueAtTime(0.12, audioContext.currentTime);
        gain.gain.exponentialRampToValueAtTime(0.001, audioContext.currentTime + d);
        osc.connect(gain);
        gain.connect(audioContext.destination);
        osc.start();
        osc.stop(audioContext.currentTime + d);
        if (navigator.vibrate) navigator.vibrate(12);
      } catch(e) {}
    }

    function playPinSuccess() {
      try {
        if (!audioContext) audioContext = new (window.AudioContext || window.webkitAudioContext)();
        if (audioContext.state === 'suspended') audioContext.resume();
        const chord = [523.25, 659.25, 783.99, 1046.50];
        chord.forEach((freq, idx) => {
          setTimeout(() => {
            try {
              const osc = audioContext.createOscillator();
              const gain = audioContext.createGain();
              osc.type = 'triangle';
              osc.frequency.setValueAtTime(freq, audioContext.currentTime);
              gain.gain.setValueAtTime(0.12, audioContext.currentTime);
              gain.gain.exponentialRampToValueAtTime(0.001, audioContext.currentTime + 0.16);
              osc.connect(gain);
              gain.connect(audioContext.destination);
              osc.start();
              osc.stop(audioContext.currentTime + 0.16);
            } catch(e) {}
          }, idx * 55);
        });
        if (navigator.vibrate) navigator.vibrate([30, 40, 50]);
      } catch(e) {}
    }

    function playPinFailure() {
      try {
        if (!audioContext) audioContext = new (window.AudioContext || window.webkitAudioContext)();
        if (audioContext.state === 'suspended') audioContext.resume();
        const osc = audioContext.createOscillator();
        const gain = audioContext.createGain();
        osc.type = 'sawtooth';
        osc.frequency.setValueAtTime(160, audioContext.currentTime);
        gain.gain.setValueAtTime(0.18, audioContext.currentTime);
        gain.gain.exponentialRampToValueAtTime(0.001, audioContext.currentTime + 0.22);
        osc.connect(gain);
        gain.connect(audioContext.destination);
        osc.start();
        osc.stop(audioContext.currentTime + 0.22);
        if (navigator.vibrate) navigator.vibrate([60, 50, 60]);
      } catch(e) {}
    }

    function handlePinKey(digit) {
      if (enteredDigits.length >= 4) return;
      playAudioClick(650 + (parseInt(digit, 10) * 35), 0.035);
      enteredDigits += digit;
      updatePinDots();
      document.getElementById('pinError').innerText = '';
      if (enteredDigits.length === 4) {
        verifyEnteredPin(enteredDigits);
      }
    }

    function handlePinClear() {
      playAudioClick(400, 0.04);
      enteredDigits = '';
      updatePinDots();
      document.getElementById('pinError').innerText = '';
    }

    function handlePinBackspace() {
      if (enteredDigits.length > 0) {
        playAudioClick(460, 0.035);
        enteredDigits = enteredDigits.slice(0, -1);
        updatePinDots();
        document.getElementById('pinError').innerText = '';
      }
    }

    window.addEventListener('keydown', (e) => {
      const modal = document.getElementById('pinModal');
      if (!modal || modal.style.display === 'none') return;
      if (e.key >= '0' && e.key <= '9') {
        handlePinKey(e.key);
      } else if (e.key === 'Backspace') {
        handlePinBackspace();
      } else if (e.key === 'Escape' || e.key === 'c' || e.key === 'C') {
        handlePinClear();
      }
    });

    function verifyEnteredPin(pinToTest) {
      const errEl = document.getElementById('pinError');
      errEl.innerText = 'Verifying PIN...';
      fetch('/api/barista/verify-pin', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ pin: pinToTest })
      })
      .then(res => res.json())
      .then(data => {
        if (data && data.valid) {
          onPinSuccess(pinToTest);
        } else {
          showPinFailure();
        }
      })
      .catch(() => showPinFailure());
    }

    function showPinFailure() {
      playPinFailure();
      const dotsEl = document.getElementById('pinDots');
      dotsEl.classList.add('shake');
      const errEl = document.getElementById('pinError');
      errEl.innerText = 'Incorrect PIN. Access Denied.';
      setTimeout(() => {
        dotsEl.classList.remove('shake');
        handlePinClear();
      }, 550);
    }

    function onPinSuccess(validPin) {
      playPinSuccess();
      authPin = validPin;
      isAuthorized = true;
      try {
        sessionStorage.setItem('celestial_barista_pin', validPin);
        localStorage.setItem('celestial_barista_pin', validPin);
      } catch(e) {}
      const card = document.querySelector('.pin-card');
      if (card) {
        card.style.transform = 'scale(1.02)';
        card.style.borderColor = 'var(--emerald-ready)';
      }
      setTimeout(() => {
        document.getElementById('pinModal').style.display = 'none';
        if (card) {
          card.style.transform = '';
          card.style.borderColor = '';
          card.style.boxShadow = '';
        }
      }, 280);
      connectWs();
      fetch('/api/orders?pin=' + encodeURIComponent(validPin))
        .then(res => res.json())
        .then(data => {
          if (data && data.orders) {
            currentOrders = data.orders;
            renderOrders(currentOrders);
          }
        })
        .catch(() => {});
    }

    function showPinModal() {
      enteredDigits = '';
      updatePinDots();
      document.getElementById('pinError').innerText = '';
      document.getElementById('pinModal').style.display = 'flex';
    }

    function lockKds() {
      authPin = '';
      isAuthorized = false;
      try {
        sessionStorage.removeItem('celestial_barista_pin');
        localStorage.removeItem('celestial_barista_pin');
      } catch(e) {}
      if (ws) {
        try { ws.close(); } catch(e) {}
        ws = null;
      }
      currentOrders = [];
      renderOrders([]);
      showPinModal();
    }

    function playChime() {
      try {
        if (!audioContext) audioContext = new (window.AudioContext || window.webkitAudioContext)();
        const doPlay = () => {
          if (!audioContext) return;
          try {
            const osc = audioContext.createOscillator();
            const gain = audioContext.createGain();
            osc.type = 'triangle';
            osc.connect(gain);
            gain.connect(audioContext.destination);
            osc.frequency.setValueAtTime(659.25, audioContext.currentTime);
            osc.frequency.setValueAtTime(1046.5, audioContext.currentTime + 0.12);
            gain.gain.setValueAtTime(0.65, audioContext.currentTime);
            gain.gain.exponentialRampToValueAtTime(0.01, audioContext.currentTime + 0.55);
            osc.start();
            osc.stop(audioContext.currentTime + 0.55);
          } catch(_) {}
        };

        if (audioContext && audioContext.state === 'suspended') {
          audioContext.resume().then(doPlay).catch(() => {});
        } else {
          doPlay();
        }

        if (navigator.vibrate) {
          navigator.vibrate([400, 150, 400]);
        }
      } catch (e) {}
    }

    function setFilter(filter, btn) {
      activeFilter = filter;
      document.querySelectorAll('.tab-btn').forEach(b => b.classList.remove('active'));
      btn.classList.add('active');
      renderOrders(currentOrders);
    }

    function connectWs() {
      if (!authPin) return;
      const loc = window.location;
      const wsUrl = (loc.protocol === 'https:' ? 'wss://' : 'ws://') + loc.host + '/ws?pin=' + encodeURIComponent(authPin);
      
      try {
        ws = new WebSocket(wsUrl);

        ws.onopen = () => {
          document.getElementById('statusBadge').className = 'status-badge';
          document.getElementById('statusText').innerText = 'Live Sync';
        };

        ws.onmessage = (event) => {
          try {
            const data = JSON.parse(event.data);
            if (data.type === 'SYNC_ORDERS') {
              currentOrders = data.orders || [];
              renderOrders(currentOrders);
            } else if (data.type === 'ITEM_PREPARED') {
              const order = (currentOrders || []).find(o => o.id === data.orderId);
              if (order && order.items && order.items[data.itemIndex]) {
                order.items[data.itemIndex].isPrepared = data.isPrepared;
                renderOrders(currentOrders);
              }
            }
          } catch (e) { console.error(e); }
        };

        ws.onclose = () => {
          document.getElementById('statusBadge').className = 'status-badge disconnected';
          document.getElementById('statusText').innerText = 'Reconnecting...';
          setTimeout(connectWs, 2500);
        };

        ws.onerror = () => { ws.close(); };
      } catch (e) {
        setTimeout(connectWs, 2500);
      }
    }

    function fetchOrdersHttp() {
      if (!authPin) return;
      fetch('/api/orders?pin=' + encodeURIComponent(authPin))
        .then(res => res.json())
        .then(data => {
          if (data && data.orders) {
            currentOrders = data.orders;
            renderOrders(currentOrders);
          }
        })
        .catch(err => console.warn('Poll err:', err));
    }

    function isItemKitchen(item) {
      if (item.isKitchen === true) return true;
      const cat = (item.category || '').toLowerCase();
      if (cat.includes('street') || cat.includes('pasta') || cat.includes('sandwich') || cat.includes('bites') || cat.includes('food')) {
        return true;
      }
      const n = (item.name || item.menuItem?.name || '').toLowerCase();
      return n.includes('buffalo') || n.includes('wing') || n.includes('fries') ||
        n.includes('stick') || n.includes('lumpia') || n.includes('shanghai') ||
        n.includes('pasta') || n.includes('carbonara') || n.includes('aglio') ||
        n.includes('sandwich') || n.includes('toast') || n.includes('burger');
    }

    function orderHasKitchen(order) {
      if (order.hasKitchenDishes === true) return true;
      return (order.items || []).some(isItemKitchen);
    }

    function orderHasBarista(order) {
      if (order.hasBaristaDrinks === true) return true;
      return (order.items || []).some(i => !isItemKitchen(i));
    }

    let prevCount = 0;
    function renderOrders(orders) {
      currentOrders = orders;
      try {
        localStorage.setItem('celestial_kds_orders_cache', JSON.stringify(orders));
      } catch(e) {}
      const active = orders.filter(o => o.status === 'confirmed' || o.status === 'inqueue' || o.status === 'preparing' || o.status === 'ready');
      
      document.getElementById('countAll').innerText = active.length;
      const countQueueEl = document.getElementById('countQueue');
      if (countQueueEl) countQueueEl.innerText = active.filter(o => o.status === 'confirmed' || o.status === 'inqueue').length;
      document.getElementById('countBrewing').innerText = active.filter(o => o.status === 'preparing').length;
      document.getElementById('countReady').innerText = active.filter(o => o.status === 'ready').length;

      const kitchenOrders = active.filter(orderHasKitchen);
      const baristaOrders = active.filter(orderHasBarista);
      const countKitchenEl = document.getElementById('countKitchen');
      if (countKitchenEl) countKitchenEl.innerText = kitchenOrders.length;
      const countBaristaEl = document.getElementById('countBarista');
      if (countBaristaEl) countBaristaEl.innerText = baristaOrders.length;

      const takeoutOrders = active.filter(o => o.orderType === 'takeaway' || o.orderType === 'takeout' || o.orderType === 'delivery' || (o.items || []).some(i => i.notes && (i.notes.toLowerCase().includes('take') || i.notes.toLowerCase().includes('to-go') || i.notes.toLowerCase().includes('togo') || i.notes.toLowerCase().includes('balot'))));
      const countTakeoutEl = document.getElementById('countTakeout');
      if (countTakeoutEl) countTakeoutEl.innerText = takeoutOrders.length;

      if (active.length > prevCount) {
        playChime();
      }
      prevCount = active.length;

      const filtered = activeFilter === 'all'
        ? active
        : (activeFilter === 'confirmed'
            ? active.filter(o => o.status === 'confirmed' || o.status === 'inqueue')
            : (activeFilter === 'kitchen'
                ? kitchenOrders
                : (activeFilter === 'barista'
                    ? baristaOrders
                    : (activeFilter === 'takeout'
                        ? takeoutOrders
                        : active.filter(o => o.status === activeFilter)))));

      const container = document.getElementById('ticketsContainer');

      if (filtered.length === 0) {
        container.innerHTML = `
          <div class="empty-state">
            <div class="empty-icon" style="font-size:36px;opacity:0.3;">—</div>
            <h3>No Active Kitchen Tickets</h3>
            <p style="font-size: 13px; margin-top: 4px;">Orders rung up on the POS will appear here live.</p>
          </div>
        `;
        return;
      }

      container.innerHTML = filtered.map(order => {
        const elapsedMins = Math.max(0, Math.floor((new Date() - new Date(order.createdAt)) / 60000));
        let timerClass = 'timer-green';
        if (elapsedMins >= 14) {
          timerClass = 'timer-red';
        } else if (elapsedMins >= 6) {
          timerClass = 'timer-amber';
        }

        let kitchenCount = 0;
        let baristaCount = 0;
        (order.items || []).forEach(i => {
          if (isItemKitchen(i)) {
            kitchenCount += (i.quantity || 1);
          } else {
            baristaCount += (i.quantity || 1);
          }
        });

        let stationBadgesHtml = '';
        if (kitchenCount > 0) {
          stationBadgesHtml += `<span class="station-badge-kitchen">\${kitchenCount} Kitchen</span>`;
        }
        if (baristaCount > 0) {
          stationBadgesHtml += `<span class="station-badge-bar">\${baristaCount} Bar</span>`;
        }

        let allItemsDone = (order.items || []).length > 0;
        const isTakeout = order.orderType === 'takeaway' || order.orderType === 'takeout' || order.orderType === 'delivery';
        const takeoutTicketClass = isTakeout ? 'takeout-ticket' : '';
        const orderTypeBadgeClass = isTakeout ? 'order-type-badge takeout-badge' : 'order-type-badge';
        const tableInfo = order.tableNumber ? ` • \${order.tableNumber}` : '';
        const orderTypeLabel = isTakeout ? '🥡 TAKE OUT' : (order.orderType === 'dineIn' ? `Dine-In\${tableInfo}` : 'Takeaway');
        const takeoutBannerHtml = isTakeout ? `<div class="takeout-banner"><span>🛍️</span> <span>TAKE OUT • PACK IN BAG (USE PAPER CUPS & LIDS)</span></div>` : '';

        const itemsHtml = (order.items || []).map((item, itemIdx) => {
          const itemName = item.name || item.menuItem?.name || 'Item';
          const isKitchen = isItemKitchen(item);
          const isDone = item.isPrepared === true;
          if (!isDone) allItemsDone = false;
          let sizeHtml = '';
          const nonSizeCustoms = [];

          (item.customizations || []).forEach(c => {
            const name = (c.optionName || '').toLowerCase();
            if (name.includes('16oz') || name.includes('16 oz')) {
              sizeHtml = '<span class="size-badge size-16oz">16 oz</span>';
            } else if (name.includes('22oz') || name.includes('22 oz')) {
              sizeHtml = '<span class="size-badge size-22oz">22 oz</span>';
            } else {
              nonSizeCustoms.push(c.summary || c.optionName);
            }
          });

          const customsListHtml = nonSizeCustoms.length > 0
            ? `<div class="custom-list">\${nonSizeCustoms.map(c => `<div class="custom-item">› \${c}</div>`).join('')}</div>`
            : '';

          const isItemTakeout = isTakeout || (item.notes && (item.notes.toLowerCase().includes('take') || item.notes.toLowerCase().includes('to-go') || item.notes.toLowerCase().includes('togo') || item.notes.toLowerCase().includes('balot')));
          const takeoutItemBadge = isItemTakeout ? '<span class="takeout-item-badge">🥡 TAKE OUT</span>' : '';

          const noteHtml = item.notes ? `<div class="note-box">📝 Note: \${item.notes}</div>` : '';
          const doneClass = isDone ? 'item-done' : '';
          const prepBadgeHtml = isDone ? '<span class="item-prepared-badge">✓ PREPARED</span>' : '';
          const kitchenTag = isKitchen ? '<div class="kitchen-tag">KITCHEN COOK DISH</div>' : '';

          const isPreparing = order.status === 'preparing';
          const rowTitle = isPreparing ? 'Click to mark as prepared' : '⚠️ Tap "Start Brewing / Prep" first before checking off items';
          const rowLockedClass = isPreparing ? '' : 'item-row-locked';
          const toggleContent = isDone ? '✓' : '';

          return `
            <div class="item-row \${isKitchen ? 'kitchen-item-row' : ''} \${doneClass} \${rowLockedClass}" onclick="toggleItemPrepared('\${order.id}', \${itemIdx}, event)" title="\${rowTitle}">
              \${kitchenTag}
              <div class="item-title-row">
                <span class="item-prep-toggle">\${toggleContent}</span>
                <span class="item-qty \${isKitchen ? 'kitchen-qty' : ''}">\${item.quantity}x</span>
                <span class="item-name \${isKitchen ? 'kitchen-name' : ''}">\${itemName}</span>
                \${sizeHtml}
                \${takeoutItemBadge}
                \${prepBadgeHtml}
              </div>
              \${customsListHtml}
              \${noteHtml}
            </div>
          `;
        }).join('');

        let actionBtn = '';
        let statusBadgeHtml = '';
        if (order.status === 'confirmed') {
          statusBadgeHtml = `<div style="background: rgba(46,196,182,0.14); border: 1.2px solid rgba(46,196,182,0.45); border-radius: 6px; padding: 4px 8px; font-size: 11px; font-weight: 800; color: #2EC4B6; margin-bottom: 8px; text-align: center; letter-spacing: 0.5px;">✓ CONFIRMED BY CASHIER</div>`;
          actionBtn = `<button class="action-btn btn-brew" onclick="confirmStatusChange('\${order.id}', '\${order.orderNumber}', 'preparing')">Start Brewing / Prep</button>`;
        } else if (order.status === 'pending') {
          statusBadgeHtml = `<div style="background: rgba(255,159,28,0.15); border: 1px solid rgba(255,159,28,0.4); border-radius: 6px; padding: 4px 8px; font-size: 11px; font-weight: bold; color: var(--amber-brewing); margin-bottom: 8px; text-align: center;">Awaiting Cashier Payment</div>`;
          actionBtn = `<button class="action-btn btn-brew" onclick="confirmStatusChange('\${order.id}', '\${order.orderNumber}', 'preparing')">Start Brewing / Confirm</button>`;
        } else if (order.status === 'preparing') {
          actionBtn = `<button class="action-btn btn-ready" onclick="confirmStatusChange('\${order.id}', '\${order.orderNumber}', 'ready')">Mark Ready for Pickup</button>`;
        } else if (order.status === 'ready') {
          actionBtn = `<button class="action-btn btn-done" onclick="confirmStatusChange('\${order.id}', '\${order.orderNumber}', 'completed')">Complete & Hand Over</button>`;
        }

        const totalItems = (order.items || []).reduce((sum, i) => sum + (i.quantity || 1), 0);

        const allPreparedHtml = (allItemsDone && (order.items || []).length > 0 && order.status === 'preparing')
          ? '<div class="all-prepared-banner">✨ All Items Prepared & Ready!</div>'
          : '';

        const ticketHasKitchen = kitchenCount > 0 ? 'has-kitchen' : '';
        return `
          <div class="ticket \${order.status} \${ticketHasKitchen} \${takeoutTicketClass}">
            <div class="ticket-header">
              <div class="ticket-title-group">
                <div class="ticket-number">\${order.orderNumber}</div>
                <div class="\${orderTypeBadgeClass}">\${orderTypeLabel}</div>
              </div>
              <div class="ticket-header-right">
                <div class="timer-badge \${timerClass}">\${elapsedMins}m ago</div>
                <button class="void-btn" onclick="voidOrder('\${order.id}', '\${order.orderNumber}')" title="Void / Cancel Ticket">✕</button>
              </div>
            </div>
            <div class="ticket-sub">
              <div style="display: flex; align-items: center; gap: 6px; flex-wrap: wrap;">
                <span class="guest-name">Guest: \${order.customerName || 'Guest Patron'}</span>
                \${stationBadgesHtml}
              </div>
              <span class="item-count-text">\${totalItems} items</span>
            </div>
            \${takeoutBannerHtml}
            <div class="ticket-body">
              \${statusBadgeHtml}
              \${itemsHtml}
            </div>
            \${order.orderNotes ? `<div class="order-memo-box">Memo: \${order.orderNotes}</div>` : ''}
            \${allPreparedHtml}
            <div class="ticket-footer">
              \${actionBtn}
            </div>
          </div>
        `;
      }).join('');
    }

    function showKdsNotification(msg, isWarning) {
      let toast = document.getElementById('kdsToast');
      if (!toast) {
        toast = document.createElement('div');
        toast.id = 'kdsToast';
        toast.style.cssText = 'position:fixed;bottom:24px;left:50%;transform:translateX(-50%);background:#18131E;border:1.5px solid #FF9F1C;color:#FFF;padding:12px 22px;border-radius:12px;font-size:13px;font-weight:700;z-index:99999;box-shadow:0 8px 32px rgba(0,0,0,0.7);transition:opacity 0.25s,transform 0.25s;pointer-events:none;display:flex;align-items:center;gap:8px;';
        document.body.appendChild(toast);
      }
      toast.innerText = msg;
      toast.style.borderColor = isWarning ? '#FF9F1C' : '#2EC4B6';
      toast.style.opacity = '1';
      toast.style.transform = 'translateX(-50%) translateY(0)';
      clearTimeout(toast._timer);
      toast._timer = setTimeout(() => {
        toast.style.opacity = '0';
        toast.style.transform = 'translateX(-50%) translateY(8px)';
      }, 2600);
    }

    function toggleItemPrepared(orderId, itemIdx, e) {
      if (e) {
        e.stopPropagation();
        e.preventDefault();
      }
      const order = (currentOrders || []).find(o => o.id === orderId);
      if (!order || !order.items || !order.items[itemIdx]) return;

      if (order.status !== 'preparing') {
        showKdsNotification('⚠️ Please tap "Start Brewing / Prep" first before checking off items', true);
        return;
      }

      const targetItem = order.items[itemIdx];
      const newPrepared = !(targetItem.isPrepared === true);
      targetItem.isPrepared = newPrepared;

      if (navigator.vibrate) {
        try { navigator.vibrate(35); } catch(_) {}
      }

      // 1. Optimistic instant screen render
      renderOrders(currentOrders);

      // 2. Real-time WebSocket sync to POS App & other live screens
      if (ws && ws.readyState === WebSocket.OPEN) {
        try {
          ws.send(JSON.stringify({
            action: 'toggle_item_prep',
            orderId: orderId,
            itemIndex: itemIdx,
            isPrepared: newPrepared,
            pin: authPin
          }));
        } catch(e) {}
      } else {
        // 3. HTTP Fallback sync only when WebSocket is not connected
        fetch('/api/orders/item-prep', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'X-Barista-Pin': authPin
          },
          body: JSON.stringify({
            orderId: orderId,
            itemIndex: itemIdx,
            isPrepared: newPrepared,
            pin: authPin
          })
        })
        .then(res => res.json())
        .then(data => {
          if (data && data.orders) {
            currentOrders = data.orders;
            renderOrders(currentOrders);
          }
        })
        .catch(() => {});
      }
    }

    let pendingKdsAction = null;
    let isKdsConfirmSubmitting = false;

    function toggleChecklistRow(row) {
      const box = row.querySelector('.kds-chk-box');
      if (box) box.classList.toggle('checked');
    }

    function closeKdsConfirmModal() {
      const modal = document.getElementById('kdsConfirmModal');
      if (modal) modal.style.display = 'none';
      pendingKdsAction = null;
      isKdsConfirmSubmitting = false;
    }

    function showKdsConfirmModal(opts) {
      isKdsConfirmSubmitting = false;
      pendingKdsAction = opts.onConfirm;

      const order = (currentOrders || []).find(o => o.id === opts.orderId) || opts.order || {};
      const card = document.getElementById('kdsConfirmCard');
      if (card) {
        card.style.borderColor = opts.borderColor || 'rgba(46, 196, 182, 0.5)';
      }

      // 1. Icon Box & Header Icon
      const iconBox = document.getElementById('kdsConfirmIconBox');
      if (iconBox) {
        iconBox.style.background = opts.iconBg || 'rgba(46, 196, 182, 0.15)';
        iconBox.style.borderColor = opts.iconBorder || 'rgba(46, 196, 182, 0.4)';
        iconBox.innerHTML = opts.headerIcon || '';
      }

      // 2. Title & Subtitle
      const titleEl = document.getElementById('kdsConfirmTitle');
      if (titleEl) {
        let orderNumDisplay = String(order.orderNumber || opts.orderNumber || '').trim();
        if (orderNumDisplay && !orderNumDisplay.startsWith('#')) {
          orderNumDisplay = '#' + orderNumDisplay;
        }
        titleEl.innerText = (opts.title || 'Confirm Action') + (orderNumDisplay ? ' • ' + orderNumDisplay : '');
      }

      const subEl = document.getElementById('kdsConfirmSubtitle');
      if (subEl) {
        const orderType = order.orderType || 'dineIn';
        const isDineIn = (orderType === 'dineIn' || orderType === 'dine_in');
        const typeLabel = isDineIn ? 'Dine-In' : 'Takeaway';
        let tableText = '';
        if (order.tableNumber) {
          const t = String(order.tableNumber).trim();
          tableText = t.toLowerCase().startsWith('table') ? t : 'Table ' + t;
        }
        subEl.innerText = isDineIn ? (typeLabel + ' • ' + (tableText || 'Table 1')) : typeLabel;
      }

      // 3. Notice Banner
      const noticeTextEl = document.getElementById('kdsConfirmNoticeText');
      if (noticeTextEl) {
        noticeTextEl.innerText = opts.noticeText || 'Kindly double check if the item is correct and complete before proceeding.';
      }

      // 4. Checklist Items
      const items = order.items || [];
      const totalPcs = items.reduce((sum, i) => sum + (i.quantity || 1), 0);
      const labelEl = document.getElementById('kdsConfirmChecklistLabel');
      if (labelEl) {
        labelEl.innerText = 'Order Items Checklist (' + totalPcs + ' pcs):';
      }

      const checklistCard = document.getElementById('kdsConfirmChecklistCard');
      if (checklistCard) {
        if (items.length === 0) {
          checklistCard.innerHTML = '<div style="color: var(--text-muted); font-size: 12px; font-style: italic; padding: 8px 4px;">No items listed in ticket</div>';
        } else {
          checklistCard.innerHTML = items.map(item => {
            const itemName = item.name || item.menuItem?.name || 'Item';
            const customs = [];
            if (item.customizations && Array.isArray(item.customizations)) {
              item.customizations.forEach(c => {
                const text = c.summary || c.optionName || '';
                if (text) customs.push(text);
              });
            }
            const customsText = customs.join(', ');
            const noteText = item.notes ? item.notes.trim() : '';

            return `
              <div class="kds-chk-item" onclick="toggleChecklistRow(this)">
                <div class="kds-chk-box">
                  <svg viewBox="0 0 24 24" fill="none" stroke="#0D0B10" stroke-width="3.6" stroke-linecap="round" stroke-linejoin="round">
                    <polyline points="20 6 9 17 4 12"></polyline>
                  </svg>
                </div>
                <div style="flex: 1; min-width: 0;">
                  <div style="font-size: 13px; line-height: 1.35;">
                    <span style="color: var(--gold-primary); font-weight: 700;">\${item.quantity || 1}x </span>
                    <span style="color: var(--text-light); font-weight: 700;">\${itemName}</span>
                  </div>
                  \${customsText ? `<div style="font-size: 11px; color: var(--gold-light); margin-top: 2px; line-height: 1.3;">› \${customsText}</div>` : ''}
                  \${noteText ? `<div style="font-size: 11px; color: var(--rose-alert); font-weight: 700; margin-top: 2px;">Note: "\${noteText}"</div>` : ''}
                </div>
              </div>
            `;
          }).join('');
        }
      }

      // 5. Action Button
      const actionBtn = document.getElementById('btnKdsConfirmAction');
      const actionIcon = document.getElementById('kdsConfirmActionIcon');
      const actionText = document.getElementById('kdsConfirmActionText');

      if (actionBtn) {
        actionBtn.disabled = false;
        actionBtn.style.opacity = '1';
        actionBtn.style.background = opts.buttonBg || 'var(--emerald-ready)';
        actionBtn.style.color = opts.buttonColor || '#0D0B10';
        actionBtn.style.boxShadow = opts.buttonShadow || '0 4px 14px rgba(46,196,182,0.35)';
      }
      if (actionIcon) actionIcon.innerHTML = opts.buttonIcon || '';
      if (actionText) actionText.innerText = opts.confirmText || 'Confirm Ready';

      document.getElementById('kdsConfirmModal').style.display = 'flex';
    }

    function confirmStatusChange(orderId, orderNumber, newStatus) {
      if (newStatus === 'ready') {
        showKdsConfirmModal({
          orderId: orderId,
          orderNumber: orderNumber,
          title: 'Mark Ready for Pickup',
          noticeText: 'Kindly double check if the item is correct and complete before proceeding.',
          confirmText: 'Confirm Ready',
          borderColor: 'rgba(46, 196, 182, 0.5)',
          iconBg: 'rgba(46, 196, 182, 0.15)',
          iconBorder: 'rgba(46, 196, 182, 0.4)',
          headerIcon: `<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="#2EC4B6" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round">
            <path d="M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9"></path>
            <path d="M13.73 21a2 2 0 0 1-3.46 0"></path>
          </svg>`,
          buttonBg: 'var(--emerald-ready)',
          buttonColor: '#0D0B10',
          buttonShadow: '0 4px 14px rgba(46, 196, 182, 0.35)',
          buttonIcon: `<svg width="15" height="15" viewBox="0 0 24 24" fill="currentColor">
            <path d="M12 22a2 2 0 0 0 2-2h-4a2 2 0 0 0 2 2zm6-6v-5a6 6 0 0 0-5-5.91V4a1 1 0 0 0-2 0v1.09A6 6 0 0 0 6 11v5l-2 2v1h16v-1l-2-2z"/>
          </svg>`,
          onConfirm: () => updateStatus(orderId, 'ready')
        });
      } else if (newStatus === 'preparing') {
        showKdsConfirmModal({
          orderId: orderId,
          orderNumber: orderNumber,
          title: 'Start Brewing',
          noticeText: 'Kindly double check recipe, size, and modifications before brewing.',
          confirmText: 'Brew Now',
          borderColor: 'rgba(255, 159, 28, 0.5)',
          iconBg: 'rgba(255, 159, 28, 0.15)',
          iconBorder: 'rgba(255, 159, 28, 0.4)',
          headerIcon: `<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="#FF9F1C" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round">
            <path d="M18 8h1a4 4 0 0 1 0 8h-1"></path>
            <path d="M2 8h16v9a4 4 0 0 1-4 4H6a4 4 0 0 1-4-4V8z"></path>
            <line x1="6" y1="1" x2="6" y2="4"></line>
            <line x1="10" y1="1" x2="10" y2="4"></line>
            <line x1="14" y1="1" x2="14" y2="4"></line>
          </svg>`,
          buttonBg: 'var(--amber-brewing)',
          buttonColor: '#0D0B10',
          buttonShadow: '0 4px 14px rgba(255, 159, 28, 0.35)',
          buttonIcon: `<svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round">
            <path d="M18 8h1a4 4 0 0 1 0 8h-1"></path>
            <path d="M2 8h16v9a4 4 0 0 1-4 4H6a4 4 0 0 1-4-4V8z"></path>
            <line x1="6" y1="1" x2="6" y2="4"></line>
            <line x1="10" y1="1" x2="10" y2="4"></line>
            <line x1="14" y1="1" x2="14" y2="4"></line>
          </svg>`,
          onConfirm: () => updateStatus(orderId, 'preparing')
        });
      } else if (newStatus === 'completed') {
        showKdsConfirmModal({
          orderId: orderId,
          orderNumber: orderNumber,
          title: 'Complete & Hand Over',
          noticeText: 'Kindly double check if all items have been served and handed over to guest.',
          confirmText: 'Complete Order',
          borderColor: 'rgba(34, 197, 94, 0.5)',
          iconBg: 'rgba(34, 197, 94, 0.15)',
          iconBorder: 'rgba(34, 197, 94, 0.4)',
          headerIcon: `<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="#22C55E" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round">
            <path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"></path>
            <polyline points="22 4 12 14.01 9 11.01"></polyline>
          </svg>`,
          buttonBg: '#22C55E',
          buttonColor: '#FFFFFF',
          buttonShadow: '0 4px 14px rgba(34, 197, 94, 0.35)',
          buttonIcon: `<svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
            <polyline points="20 6 9 17 4 12"></polyline>
          </svg>`,
          onConfirm: () => updateStatus(orderId, 'completed')
        });
      }
    }

    function voidOrder(orderId, orderNumber) {
      showKdsConfirmModal({
        orderId: orderId,
        orderNumber: orderNumber,
        title: 'Void Order',
        noticeText: 'Are you sure you want to cancel and remove this ticket from the kitchen queue? All items will be returned to stock.',
        confirmText: 'Void Ticket',
        borderColor: 'rgba(231, 29, 54, 0.5)',
        iconBg: 'rgba(231, 29, 54, 0.15)',
        iconBorder: 'rgba(231, 29, 54, 0.4)',
        headerIcon: `<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="#E71D36" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round">
          <circle cx="12" cy="12" r="10"></circle>
          <line x1="15" y1="9" x2="9" y2="15"></line>
          <line x1="9" y1="9" x2="15" y2="15"></line>
        </svg>`,
        buttonBg: '#E71D36',
        buttonColor: '#FFFFFF',
        buttonShadow: '0 4px 14px rgba(231, 29, 54, 0.35)',
        buttonIcon: `<svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
          <polyline points="3 6 5 6 21 6"></polyline>
          <path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"></path>
        </svg>`,
        onConfirm: () => updateStatus(orderId, 'cancelled')
      });
    }

    function updateStatus(orderId, newStatus, btn) {
      if (btn) {
        btn.disabled = true;
        const actionLabel = newStatus === 'preparing'
          ? 'Brewing...'
          : (newStatus === 'ready' ? 'Marking Ready...' : 'Completing...');
        btn.innerHTML = '<span class="btn-spinner"></span><span>' + actionLabel + '</span>';
      }

      const idx = currentOrders.findIndex(o => o.id === orderId);
      if (idx >= 0) {
        if (newStatus === 'completed' || newStatus === 'cancelled') {
          currentOrders.splice(idx, 1);
        } else {
          currentOrders[idx].status = newStatus;
        }
        if (newStatus === 'completed' || newStatus === 'cancelled' || newStatus === 'ready') {
          for (const k of Array.from(preparedItemKeys)) {
            if (k.startsWith(orderId + '_')) preparedItemKeys.delete(k);
          }
          try {
            sessionStorage.setItem('celestial_kds_prepared_items', JSON.stringify([...preparedItemKeys]));
          } catch(e) {}
        }
        renderOrders(currentOrders);
      }

      if (ws && ws.readyState === WebSocket.OPEN) {
        try {
          ws.send(JSON.stringify({
            action: 'update_status',
            orderId: orderId,
            status: newStatus,
            pin: authPin
          }));
        } catch (e) {}
      } else {
        fetch('/api/orders/update-status', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'X-Barista-Pin': authPin
          },
          body: JSON.stringify({ orderId: orderId, status: newStatus, pin: authPin })
        })
        .then(res => res.json())
        .then(data => {
          if (data && data.orders) {
            renderOrders(data.orders);
          }
        })
        .catch(err => {
          console.warn('HTTP status sync fallback error:', err);
        });
      }
    }

    const kdsConfirmBtn = document.getElementById('btnKdsConfirmAction');
    if (kdsConfirmBtn) {
      kdsConfirmBtn.onclick = () => {
        if (isKdsConfirmSubmitting) return;
        isKdsConfirmSubmitting = true;
        const fn = pendingKdsAction;
        const actionBtn = document.getElementById('btnKdsConfirmAction');
        const actionIcon = document.getElementById('kdsConfirmActionIcon');
        const actionText = document.getElementById('kdsConfirmActionText');

        if (actionBtn) {
          actionBtn.disabled = true;
          actionBtn.style.opacity = '0.85';
        }
        if (actionIcon) {
          actionIcon.innerHTML = '<span class="btn-spinner" style="width:13px;height:13px;border-width:2px;margin-right:2px;"></span>';
        }
        if (actionText) {
          const currentText = actionText.innerText;
          if (currentText.includes('Ready')) actionText.innerText = 'Marking Ready...';
          else if (currentText.includes('Brew')) actionText.innerText = 'Starting Brew...';
          else if (currentText.includes('Complete')) actionText.innerText = 'Completing...';
          else if (currentText.includes('Void')) actionText.innerText = 'Voiding...';
        }

        setTimeout(() => {
          closeKdsConfirmModal();
          if (typeof fn === 'function') fn();
        }, 100);
      };
    }

    // KDS Live Text Zoom & Font Scaling System (Persistent across shifts)
    let currentKdsZoom = 1.0;

    function initKdsZoom() {
      try {
        const saved = localStorage.getItem('celestial_kds_text_zoom');
        if (saved) {
          const z = parseFloat(saved);
          if (!isNaN(z) && z >= 0.8 && z <= 2.2) {
            setKdsZoom(z, false);
            return;
          }
        }
      } catch(e) {}
      setKdsZoom(1.0, false);
    }

    function setKdsZoom(val, save = true) {
      currentKdsZoom = Math.min(2.2, Math.max(0.85, Math.round(val * 100) / 100));
      document.documentElement.style.setProperty('--kds-zoom', currentKdsZoom);
      const lbl = document.getElementById('kdsZoomLabel');
      if (lbl) lbl.textContent = Math.round(currentKdsZoom * 100) + '%';
      
      document.querySelectorAll('.zoom-pill').forEach(btn => {
        const bz = parseFloat(btn.getAttribute('data-zoom'));
        if (Math.abs(bz - currentKdsZoom) < 0.08) {
          btn.classList.add('active');
        } else {
          btn.classList.remove('active');
        }
      });

      if (save) {
        try { localStorage.setItem('celestial_kds_text_zoom', currentKdsZoom); } catch(e){}
      }
    }

    function adjustKdsZoom(delta) {
      setKdsZoom(currentKdsZoom + delta);
    }

    // Live automatic sync fallback: only poll if WebSocket is not open
    setInterval(() => {
      if (isAuthorized && authPin && (!ws || ws.readyState !== WebSocket.OPEN)) {
        fetchOrdersHttp();
      }
    }, 3500);

    // Initialize display zoom on load
    initKdsZoom();

    // Fast-boot: If previously authenticated, launch immediately with 0 delay
    if (authPin) {
      onPinSuccess(authPin);
    } else {
      showPinModal();
    }
  </script>
</body>
</html>
''';