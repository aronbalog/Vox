(() => {
  'use strict';

  const $ = (selector, root = document) => root.querySelector(selector);
  const $$ = (selector, root = document) => Array.from(root.querySelectorAll(selector));
  const escapeHTML = text => text.replace(/[&<>"]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));
  const reducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  const finePointer = window.matchMedia('(hover: hover) and (pointer: fine)').matches;

  // Plays a class's animation again from the start.
  function restart(element, name) {
    element.classList.remove(name);
    void element.offsetWidth;
    element.classList.add(name);
  }

  // Highlighting

  const swiftKeywords = 'actor|any|as|async|await|break|case|catch|class|continue|default|defer|do|else|enum|extension|false|final|for|func|guard|if|import|in|init|inout|is|let|nil|open|override|private|protocol|public|return|self|Self|some|static|struct|super|switch|throw|throws|true|try|typealias|var|where|while';

  const grammars = {
    swift: [
      ['c', /\/\/[^\n]*/y],
      ['s', /"(?:[^"\\\n]|\\.)*"/y],
      ['a', /@[A-Za-z_]\w*/y],
      ['k', new RegExp(`\\b(?:${swiftKeywords})\\b`, 'y')],
      ['t', /\b[A-Z][A-Za-z0-9_]*\b/y],
      ['n', /\b\d+(?:\.\d+)?\b/y],
      ['m', /\.[a-z_][A-Za-z0-9_]*/y],
      ['', /[a-z_][A-Za-z0-9_]*/y],
      ['p', /[{}()[\]<>,:;=!?&|+\-*\/]/y],
    ],
    json: [
      ['jk', /"(?:[^"\\\n]|\\.)*"(?=\s*:)/y],
      ['js', /"(?:[^"\\\n]|\\.)*"/y],
      ['n', /-?\b\d+(?:\.\d+)?(?:[eE][+-]?\d+)?\b/y],
      ['k', /\b(?:true|false|null)\b/y],
      ['c', /\/\/[^\n]*/y],
      ['p', /[{}[\],:]/y],
    ],
    ruby: [
      ['c', /#[^\n]*/y],
      ['s', /'(?:[^'\\\n]|\\.)*'|"(?:[^"\\\n]|\\.)*"/y],
      ['k', /\b(?:pod|target|do|end|platform)\b/y],
      ['', /[A-Za-z_]\w*/y],
    ],
  };

  function highlight(code, lang) {
    if (lang === 'http') {
      return highlightHTTP(code);
    }

    const grammar = grammars[lang];

    if (!grammar) {
      return escapeHTML(code);
    }

    let html = '';
    let plain = '';
    let index = 0;

    scan: while (index < code.length) {
      for (const [kind, pattern] of grammar) {
        pattern.lastIndex = index;
        const match = pattern.exec(code);

        if (match && match[0].length) {
          const text = match[0];
          html += escapeHTML(plain);
          plain = '';

          if (!kind) {
            html += escapeHTML(text);
          } else if (kind === 'm') {
            html += `<span class="tok-p">.</span><span class="tok-m">${escapeHTML(text.slice(1))}</span>`;
          } else {
            html += `<span class="tok-${kind}">${escapeHTML(text)}</span>`;
          }

          index += text.length;
          continue scan;
        }
      }

      plain += code[index];
      index += 1;
    }

    return html + escapeHTML(plain);
  }

  function highlightHTTP(code) {
    const blank = code.indexOf('\n\n');
    const head = blank < 0 ? code : code.slice(0, blank);
    const body = blank < 0 ? '' : code.slice(blank + 2);

    const lines = head.split('\n').map((line, index) => {
      const request = index === 0 && line.match(/^([A-Z]+) (\S+)(?: (HTTP\/[\d.]+))?$/);

      if (request) {
        return `<span class="tok-method">${request[1]}</span> <span class="tok-path">${escapeHTML(request[2])}</span>` +
          (request[3] ? ` <span class="tok-c">${request[3]}</span>` : '');
      }

      const header = line.match(/^([\w-]+):(.*)$/);

      return header
        ? `<span class="tok-hn">${escapeHTML(header[1])}</span><span class="tok-p">:</span>${escapeHTML(header[2])}`
        : escapeHTML(line);
    });

    return lines.join('\n') + (blank < 0 ? '' : '\n\n' + highlight(body, 'json'));
  }

  const languageOf = element => (element.className.match(/lang-(\w+)/) || [])[1];
  const sourceOf = new WeakMap();

  function paint(element) {
    const source = element.textContent.replace(/\r\n?/g, '\n').replace(/^\n+|\n+$/g, '');
    sourceOf.set(element, source);
    element.innerHTML = highlight(source, languageOf(element));
  }

  // Copying

  async function copyText(text) {
    try {
      await navigator.clipboard.writeText(text);
    } catch {
      const area = document.createElement('textarea');
      area.value = text;
      area.setAttribute('readonly', '');
      area.style.position = 'fixed';
      area.style.opacity = '0';
      document.body.append(area);
      area.select();
      document.execCommand('copy');
      area.remove();
    }
  }

  function flash(button, label, doneLabel = 'Copied') {
    button.classList.add('done');
    label.textContent = doneLabel;
    clearTimeout(button.flashTimer);
    button.flashTimer = setTimeout(() => {
      button.classList.remove('done');
      label.textContent = 'Copy';
    }, 1600);
  }

  function addCopyButtons() {
    for (const bar of $$('.window > .window-bar')) {
      const code = $('pre code', bar.parentElement);

      if (!code) {
        continue;
      }

      const button = document.createElement('button');
      button.type = 'button';
      button.className = 'copy';
      button.textContent = 'Copy';
      button.setAttribute('aria-label', 'Copy code');
      button.addEventListener('click', async () => {
        await copyText(sourceOf.get(code) ?? code.textContent);
        flash(button, button);
      });
      bar.append(button);
    }

    for (const button of $$('[data-copy]')) {
      const label = $('span', button) ?? button;
      button.addEventListener('click', async () => {
        await copyText(button.dataset.copy);
        flash(button, label);
      });
    }
  }

  // Tabs

  function initTabs() {
    for (const list of $$('[role="tablist"]')) {
      const tabs = $$('[role="tab"]', list);

      const select = (tab, focus) => {
        for (const other of tabs) {
          const selected = other === tab;
          other.setAttribute('aria-selected', String(selected));
          other.tabIndex = selected ? 0 : -1;
          const panel = document.getElementById(other.getAttribute('aria-controls'));

          if (panel) {
            panel.hidden = !selected;

            if (selected) {
              panel.classList.remove('fade-in');
              void panel.offsetWidth;
              panel.classList.add('fade-in');
            }
          }
        }

        if (focus) {
          tab.focus();
        }

        list.dispatchEvent(new CustomEvent('tabchange', { detail: tab }));
      };

      list.selectTab = select;

      for (const tab of tabs) {
        tab.addEventListener('click', () => select(tab, false));
        tab.addEventListener('keydown', event => {
          const index = tabs.indexOf(tab);
          const next = { ArrowRight: index + 1, ArrowLeft: index - 1, Home: 0, End: tabs.length - 1 }[event.key];

          if (next !== undefined) {
            event.preventDefault();
            select(tabs[(next + tabs.length) % tabs.length], true);
          }
        });
      }
    }
  }

  // Document explorer

  function initExplorer() {
    const explorer = $('#explorer');

    if (!explorer) {
      return;
    }

    const code = $('#explorer-json code');
    const pre = $('#explorer-json');
    const source = code.textContent.replace(/\r\n?/g, '\n').replace(/^\n+|\n+$/g, '');
    sourceOf.set(code, source);
    code.innerHTML = source
      .split('\n')
      .map((line, index) => `<span class="line" data-n="${index + 1}">${highlight(line, 'json') || ' '}</span>`)
      .join('');

    const lines = $$('.line', code);
    const list = $('[role="tablist"]', explorer);
    const tabs = $$('[role="tab"]', list);

    const parts = tabs.map(tab => {
      const panel = document.getElementById(tab.getAttribute('aria-controls'));
      const numbers = new Set();

      for (const range of panel.dataset.lines.split(',')) {
        const [start, end = start] = range.split('-').map(Number);

        for (let n = start; n <= end; n += 1) {
          numbers.add(n);
        }
      }

      return { tab, numbers };
    });

    const scan = document.createElement('span');
    scan.className = 'scan';
    scan.setAttribute('aria-hidden', 'true');
    pre.parentElement.append(scan);

    const show = tab => {
      const part = parts.find(candidate => candidate.tab === tab);

      pre.classList.add('focused');
      lines.forEach((line, index) => line.classList.toggle('on', part.numbers.has(index + 1)));

      const first = lines[Math.min(...part.numbers) - 1];
      const top = first.offsetTop - pre.clientHeight * 0.2;
      pre.scrollTo({ top: Math.max(0, top), behavior: reducedMotion ? 'auto' : 'smooth' });
      restart(scan, 'run');
    };

    list.addEventListener('tabchange', event => show(event.detail));

    const specificity = ['identity', 'attributes', 'links', 'relationships', 'included', 'data', 'toplevel'];

    code.addEventListener('click', event => {
      const line = event.target.closest('.line');

      if (!line) {
        return;
      }

      const n = Number(line.dataset.n);

      for (const name of specificity) {
        const part = parts.find(candidate => candidate.tab.id === `tab-${name}` && candidate.numbers.has(n));

        if (part) {
          list.selectTab(part.tab, false);
          return;
        }
      }
    });

    show(tabs[0]);
  }

  // Query builder

  function initPlayground() {
    const root = $('#playground');

    if (!root) {
      return;
    }

    const state = {
      target: 'collection',
      include: ['author', 'comments.author'],
      fields: { articles: ['title', 'author'], people: ['firstName'] },
      sort: [{ field: 'publishedAt', descending: true }],
    };

    const order = {
      include: $$('[data-control="include"] .chip', root).map(chip => chip.dataset.value),
      fields: Object.fromEntries($$('[data-control="fields"]', root).map(group => [group.dataset.type, $$('.chip', group).map(chip => chip.dataset.value)])),
    };

    const input = id => $(`#${id}`, root);
    const http = $('#pg-http');
    const swift = $('#pg-swift');
    let rendered = false;

    // The characters `ClientRequest.url(relativeTo:)` leaves unescaped in query components.
    const unescaped = /[A-Za-z0-9!$'()*,\-./:;?@_~]/;
    const encode = text => input('encode').checked
      ? Array.from(text, c => (unescaped.test(c) ? c : encodeURIComponent(c))).join('')
      : text;

    const swiftString = text => `"${text.replace(/\\/g, '\\\\').replace(/"/g, '\\"')}"`;
    const integer = id => (/^\d+$/.test(input(id).value.trim()) ? input(id).value.trim() : null);

    function pagination() {
      switch (input('page-strategy').value) {
        case 'page': {
          const args = [['number', integer('page-number')], ['size', integer('page-size')]].filter(([, value]) => value !== null);
          return args.length && {
            items: args.map(([name, value]) => [`page[${name}]`, value]),
            swift: `Pagination.PageBased(${args.map(([name, value]) => `${name}: ${value}`).join(', ')})`,
          };
        }
        case 'offset': {
          const args = [['offset', integer('page-offset')], ['limit', integer('page-limit')]].filter(([, value]) => value !== null);
          return args.length && {
            items: args.map(([name, value]) => [`page[${name}]`, value]),
            swift: `Pagination.OffsetBased(${args.map(([name, value]) => `${name}: ${value}`).join(', ')})`,
          };
        }
        case 'cursor': {
          const cursor = input('page-cursor').value;
          return cursor && {
            items: [['page[cursor]', cursor]],
            swift: `Pagination.CursorBased(cursor: ${swiftString(cursor)})`,
          };
        }
        default:
          return null;
      }
    }

    function render() {
      const collection = state.target === 'collection';
      const include = order.include.filter(path => state.include.includes(path));
      const fieldTypes = Object.keys(order.fields).filter(type => state.fields[type].length);
      const fields = Object.fromEntries(fieldTypes.map(type => [type, order.fields[type].filter(name => state.fields[type].includes(name))]));
      const filterKey = input('filter-key').value.trim();
      const filterValue = input('filter-value').value;
      const filter = collection && filterKey && filterValue ? { key: filterKey, value: filterValue } : null;
      const sort = collection ? state.sort : [];
      const page = collection ? pagination() : null;

      const items = [];

      for (const type of [...fieldTypes].sort()) {
        items.push(['fields', `fields[${type}]`, fields[type].join(',')]);
      }

      if (filter) {
        items.push(['filter', `filter[${filter.key}]`, filter.value]);
      }

      if (include.length) {
        items.push(['include', 'include', include.join(',')]);
      }

      if (sort.length) {
        items.push(['sort', 'sort', sort.map(s => (s.descending ? '-' : '') + s.field).join(',')]);
      }

      for (const [name, value] of page ? page.items : []) {
        items.push(['page', name, value]);
      }

      const query = items
        .map(([family, name, value]) => `<span class="qp-${family}">${escapeHTML(encode(name))}=${escapeHTML(encode(value))}</span>`)
        .join('<span class="tok-p">&amp;</span>');

      http.innerHTML =
        `<span class="tok-method">GET</span> <span class="tok-path">${collection ? '/articles' : '/articles/1'}</span>` +
        (query ? `<span class="tok-p">?</span>${query}` : '') +
        ` <span class="tok-c">HTTP/1.1</span>\n<span class="tok-hn">Accept</span><span class="tok-p">:</span> application/vnd.api+json`;
      sourceOf.set(http, http.textContent);

      const lines = ['let document = try await articles', collection ? '    .fetch()' : '    .fetch(id: "1")'];

      if (include.length) {
        lines.push(`    .include([${include.map(swiftString).join(', ')}])`);
      }

      if (fieldTypes.length) {
        lines.push(`    .fields([${fieldTypes.map(type => `${swiftString(type)}: [${fields[type].map(swiftString).join(', ')}]`).join(', ')}])`);
      }

      if (filter) {
        lines.push(`    .filter(Filter([${swiftString(filter.key)}: ${swiftString(filter.value)}]))`);
      }

      if (sort.length) {
        lines.push(`    .sort([${sort.map(s => `.${s.descending ? 'descending' : 'ascending'}(${swiftString(s.field)})`).join(', ')}])`);
      }

      if (page) {
        lines.push(`    .paginate(${page.swift})`);
      }

      lines.push('    .result()', '', collection ? 'document.data // [Article]?' : 'document.data // Article?');

      const source = lines.join('\n');
      sourceOf.set(swift, source);
      swift.innerHTML = highlight(source, 'swift');

      for (const chip of $$('[data-control="target"] .chip', root)) {
        chip.setAttribute('aria-pressed', String(chip.dataset.value === state.target));
      }

      for (const chip of $$('[data-control="include"] .chip', root)) {
        chip.setAttribute('aria-pressed', String(state.include.includes(chip.dataset.value)));
      }

      for (const group of $$('[data-control="fields"]', root)) {
        for (const chip of $$('.chip', group)) {
          chip.setAttribute('aria-pressed', String(state.fields[group.dataset.type].includes(chip.dataset.value)));
        }
      }

      for (const chip of $$('[data-control="sort"] .chip', root)) {
        const position = state.sort.findIndex(s => s.field === chip.dataset.value);
        const entry = state.sort[position];
        chip.setAttribute('aria-pressed', String(Boolean(entry)));
        chip.innerHTML = escapeHTML(chip.dataset.value) +
          (entry ? ` ${entry.descending ? '↓' : '↑'}${state.sort.length > 1 ? ` <span class="order">${position + 1}</span>` : ''}` : '');
        chip.setAttribute('aria-label', entry
          ? `${chip.dataset.value}, ${entry.descending ? 'descending' : 'ascending'}`
          : `${chip.dataset.value}, not sorted`);
      }

      for (const fieldset of $$('[data-collection]', root)) {
        fieldset.disabled = !collection;
      }

      const strategy = input('page-strategy').value;

      for (const group of $$('[data-strategy]', root)) {
        group.hidden = group.dataset.strategy !== strategy;
      }

      if (rendered) {
        restart(http.closest('.window'), 'ping');
      }

      rendered = true;
    }

    const toggle = (list, value) => (list.includes(value) ? list.filter(item => item !== value) : [...list, value]);

    root.addEventListener('click', event => {
      const chip = event.target.closest('.chip');

      if (!chip || chip.disabled) {
        return;
      }

      const group = chip.parentElement;
      const value = chip.dataset.value;

      switch (group.dataset.control) {
        case 'target':
          state.target = value;
          break;
        case 'include':
          state.include = toggle(state.include, value);
          break;
        case 'fields':
          state.fields[group.dataset.type] = toggle(state.fields[group.dataset.type], value);
          break;
        case 'sort': {
          const entry = state.sort.find(s => s.field === value);

          if (!entry) {
            state.sort = [...state.sort, { field: value, descending: false }];
          } else if (!entry.descending) {
            entry.descending = true;
          } else {
            state.sort = state.sort.filter(s => s !== entry);
          }
          break;
        }
        default:
          return;
      }

      render();
    });

    root.addEventListener('input', render);
    root.addEventListener('change', render);
    render();
  }

  // Scrolling

  function initReveal() {
    const items = $$('.reveal');

    if (!('IntersectionObserver' in window) || reducedMotion) {
      items.forEach(item => item.classList.add('in'));
      return;
    }

    for (const grid of $$('.cards, .endpoints')) {
      $$(':scope > .reveal', grid).forEach((item, index) => {
        item.style.transitionDelay = `${(index % 4) * 70}ms`;
      });
    }

    // Revealed elements go back to their own transitions, such as the hover lift of cards.
    const settle = item => {
      const delay = parseFloat(item.style.transitionDelay) || 0;
      setTimeout(() => {
        item.classList.remove('reveal', 'in');
        item.style.transitionDelay = '';
      }, 900 + delay);
    };

    const observer = new IntersectionObserver(entries => {
      for (const entry of entries) {
        if (entry.isIntersecting) {
          entry.target.classList.add('in');
          observer.unobserve(entry.target);
          settle(entry.target);
        }
      }
    }, { rootMargin: '0px 0px -8% 0px', threshold: 0.08 });

    items.forEach(item => observer.observe(item));
  }

  function initNavigation() {
    const nav = $('.nav');
    const onScroll = () => nav.classList.toggle('scrolled', window.scrollY > 8);
    window.addEventListener('scroll', onScroll, { passive: true });
    onScroll();

    if (!('IntersectionObserver' in window)) {
      return;
    }

    const links = new Map($$('.nav-links a').map(link => [link.getAttribute('href').slice(1), link]));
    const visible = new Map();

    const observer = new IntersectionObserver(entries => {
      for (const entry of entries) {
        visible.set(entry.target.id, entry.isIntersecting ? entry.intersectionRatio : 0);
      }

      let current = null;

      for (const [id, ratio] of visible) {
        if (ratio > 0 && links.has(id)) {
          current = id;
          break;
        }
      }

      links.forEach((link, id) => link.classList.toggle('active', id === current));
    }, { rootMargin: '-35% 0px -55% 0px', threshold: [0, 0.01] });

    $$('main section[id]').forEach(section => {
      visible.set(section.id, 0);
      observer.observe(section);
    });
  }

  function initSpotlight() {
    document.addEventListener('pointermove', event => {
      const target = event.target.closest?.('.card, .spot');

      if (!target) {
        return;
      }

      const rect = target.getBoundingClientRect();
      target.style.setProperty('--mx', `${event.clientX - rect.left}px`);
      target.style.setProperty('--my', `${event.clientY - rect.top}px`);
    }, { passive: true });
  }

  // Effects

  // Types the hero code one line at a time, and then the request it sends.
  function initTyping() {
    const codes = $$('.hero pre code');

    if (reducedMotion || !codes.length) {
      return;
    }

    let delay = 400;

    codes.forEach((code, index) => {
      const text = sourceOf.get(code).split('\n');
      const html = code.innerHTML.split('\n');
      const last = index === codes.length - 1;

      code.innerHTML = html.map((line, n) => {
        const caret = last && n === html.length - 1;
        const length = Math.max(text[n].length, 1) + (caret ? 1 : 0);
        const span = `<span class="tl" style="--n: ${length}; --d: ${delay}ms">${line || ' '}${caret ? '<span class="caret"></span>' : ''}</span>`;
        delay += length * 8 + 30;
        return span;
      }).join('');

      code.classList.add('typing');
      delay += 300;
    });
  }

  // Decodes the eyebrows from random glyphs when they scroll into view.
  function initScramble() {
    if (reducedMotion || !('IntersectionObserver' in window)) {
      return;
    }

    const glyphs = '{}[]<>/:=+*#_01ABCDEFXYZ';

    const decode = element => {
      const text = element.dataset.text;
      const start = performance.now();
      const duration = 300 + text.length * 32;

      const step = now => {
        const progress = (now - start) / duration;
        element.textContent = Array.from(text, (c, index) => {
          if (c === ' ' || progress * text.length * 1.4 - index * 1.1 > 0.6) {
            return c;
          }
          return glyphs[Math.floor(Math.random() * glyphs.length)];
        }).join('');

        if (progress < 1) {
          requestAnimationFrame(step);
        } else {
          element.textContent = text;
        }
      };

      requestAnimationFrame(step);
    };

    const observer = new IntersectionObserver(entries => {
      for (const entry of entries) {
        if (entry.isIntersecting) {
          observer.unobserve(entry.target);
          decode(entry.target);
        }
      }
    }, { threshold: 1 });

    for (const eyebrow of $$('.eyebrow')) {
      const text = eyebrow.textContent;
      eyebrow.innerHTML = `<span class="sr-only">${escapeHTML(text)}</span><span aria-hidden="true"></span>`;
      const visual = eyebrow.lastElementChild;
      visual.dataset.text = text;
      visual.textContent = text;
      observer.observe(visual);
    }
  }

  // A graph of drifting nodes behind the hero, with packets that travel along its links.
  function initNetwork() {
    const canvas = $('.network');

    if (!canvas || reducedMotion || !canvas.getContext) {
      return;
    }

    const context = canvas.getContext('2d');
    const hero = canvas.parentElement;
    const colors = ['255, 138, 61', '255, 77, 141', '139, 92, 246', '34, 211, 238'];
    const reach = 140;
    let width = 0;
    let height = 0;
    let nodes = [];
    let packets = [];
    let pointer = null;
    let visible = false;
    let frame = 0;
    let tick = 0;

    const spawn = () => ({
      x: Math.random() * width,
      y: Math.random() * height,
      vx: (Math.random() - 0.5) * 0.32,
      vy: (Math.random() - 0.5) * 0.32,
      r: 1 + Math.random() * 1.5,
      color: colors[Math.floor(Math.random() * colors.length)],
    });

    const resize = () => {
      const ratio = Math.min(window.devicePixelRatio || 1, 2);
      width = canvas.clientWidth;
      height = canvas.clientHeight;
      canvas.width = Math.round(width * ratio);
      canvas.height = Math.round(height * ratio);
      context.setTransform(ratio, 0, 0, ratio, 0, 0);
      const count = Math.min(90, Math.round((width * height) / 15000));
      nodes = Array.from({ length: count }, (_, index) => nodes[index] ?? spawn());
      packets = [];

      for (const node of nodes) {
        node.x = Math.min(node.x, width);
        node.y = Math.min(node.y, height);
      }
    };

    const draw = () => {
      tick += 1;
      context.clearRect(0, 0, width, height);

      for (const node of nodes) {
        node.x += node.vx;
        node.y += node.vy;

        if (node.x < 0) node.vx = Math.abs(node.vx);
        if (node.x > width) node.vx = -Math.abs(node.vx);
        if (node.y < 0) node.vy = Math.abs(node.vy);
        if (node.y > height) node.vy = -Math.abs(node.vy);

        if (pointer) {
          const dx = node.x - pointer.x;
          const dy = node.y - pointer.y;
          const distance = Math.hypot(dx, dy);

          if (distance < 120 && distance > 0.1) {
            node.x += (dx / distance) * (120 - distance) * 0.02;
            node.y += (dy / distance) * (120 - distance) * 0.02;
          }
        }
      }

      context.lineWidth = 1;

      for (let i = 0; i < nodes.length; i += 1) {
        for (let j = i + 1; j < nodes.length; j += 1) {
          const a = nodes[i];
          const b = nodes[j];
          const distance = Math.hypot(a.x - b.x, a.y - b.y);

          if (distance < reach) {
            context.strokeStyle = `rgba(${a.color}, ${(1 - distance / reach) * 0.22})`;
            context.beginPath();
            context.moveTo(a.x, a.y);
            context.lineTo(b.x, b.y);
            context.stroke();
          }
        }
      }

      if (pointer) {
        for (const node of nodes) {
          const distance = Math.hypot(node.x - pointer.x, node.y - pointer.y);

          if (distance < 200) {
            context.strokeStyle = `rgba(${node.color}, ${(1 - distance / 200) * 0.45})`;
            context.beginPath();
            context.moveTo(pointer.x, pointer.y);
            context.lineTo(node.x, node.y);
            context.stroke();
          }
        }
      }

      for (const node of nodes) {
        context.fillStyle = `rgba(${node.color}, 0.75)`;
        context.beginPath();
        context.arc(node.x, node.y, node.r, 0, Math.PI * 2);
        context.fill();
      }

      if (tick % 18 === 0 && packets.length < 14 && nodes.length > 1) {
        const from = nodes[Math.floor(Math.random() * nodes.length)];
        const near = nodes.filter(node => node !== from && Math.hypot(node.x - from.x, node.y - from.y) < reach);
        const to = near[Math.floor(Math.random() * near.length)];

        if (to) {
          packets.push({ from, to, t: 0 });
        }
      }

      packets = packets.filter(packet => {
        packet.t += 0.018;
        const x = packet.from.x + (packet.to.x - packet.from.x) * packet.t;
        const y = packet.from.y + (packet.to.y - packet.from.y) * packet.t;
        const glow = context.createRadialGradient(x, y, 0, x, y, 7);
        glow.addColorStop(0, `rgba(${packet.from.color}, 0.95)`);
        glow.addColorStop(1, `rgba(${packet.from.color}, 0)`);
        context.fillStyle = glow;
        context.beginPath();
        context.arc(x, y, 7, 0, Math.PI * 2);
        context.fill();
        return packet.t < 1;
      });
    };

    const loop = () => {
      draw();
      frame = requestAnimationFrame(loop);
    };

    const update = () => {
      cancelAnimationFrame(frame);

      if (visible && !document.hidden) {
        frame = requestAnimationFrame(loop);
      }
    };

    hero.addEventListener('pointermove', event => {
      const rect = canvas.getBoundingClientRect();
      pointer = { x: event.clientX - rect.left, y: event.clientY - rect.top };
    }, { passive: true });
    hero.addEventListener('pointerleave', () => { pointer = null; });

    new ResizeObserver(resize).observe(canvas);
    new IntersectionObserver(([entry]) => {
      visible = entry.isIntersecting;
      update();
    }).observe(canvas);
    document.addEventListener('visibilitychange', update);
  }

  // A soft light that follows the pointer.
  function initAura() {
    const aura = $('.aura');

    if (!aura || reducedMotion || !finePointer) {
      return;
    }

    let x = window.innerWidth / 2;
    let y = window.innerHeight / 3;
    let targetX = x;
    let targetY = y;
    let frame = 0;

    const step = () => {
      x += (targetX - x) * 0.12;
      y += (targetY - y) * 0.12;
      aura.style.transform = `translate3d(${x.toFixed(1)}px, ${y.toFixed(1)}px, 0)`;
      frame = Math.abs(targetX - x) + Math.abs(targetY - y) > 0.5 ? requestAnimationFrame(step) : 0;
    };

    window.addEventListener('pointermove', event => {
      targetX = event.clientX;
      targetY = event.clientY;
      aura.classList.add('on');

      if (!frame) {
        frame = requestAnimationFrame(step);
      }
    }, { passive: true });

    document.documentElement.addEventListener('pointerleave', () => aura.classList.remove('on'));
  }

  // Tilts the hero and the cards toward the pointer.
  function initTilt() {
    if (reducedMotion || !finePointer) {
      return;
    }

    for (const element of $$('.hero-visual, .cards > .card')) {
      const max = element.classList.contains('card') ? 5 : 6;
      let rect = null;

      element.classList.add('tilt');
      element.addEventListener('pointerenter', () => {
        rect = element.getBoundingClientRect();
      });
      element.addEventListener('pointermove', event => {
        rect ??= element.getBoundingClientRect();
        const x = (event.clientX - rect.left) / rect.width - 0.5;
        const y = (event.clientY - rect.top) / rect.height - 0.5;
        element.style.setProperty('--ry', `${(x * max * 2).toFixed(2)}deg`);
        element.style.setProperty('--rx', `${(-y * max * 2).toFixed(2)}deg`);
        element.classList.add('tilting');
      });
      element.addEventListener('pointerleave', () => {
        rect = null;
        element.style.setProperty('--rx', '0deg');
        element.style.setProperty('--ry', '0deg');
        element.classList.remove('tilting');
      });
    }
  }

  // Pulls the call-to-action buttons toward the pointer.
  function initMagnetic() {
    if (reducedMotion || !finePointer) {
      return;
    }

    for (const button of $$('.cta .btn')) {
      button.classList.add('magnetic');
      button.addEventListener('pointermove', event => {
        const rect = button.getBoundingClientRect();
        button.style.setProperty('--tx', `${((event.clientX - rect.left - rect.width / 2) * 0.22).toFixed(1)}px`);
        button.style.setProperty('--ty', `${((event.clientY - rect.top - rect.height / 2) * 0.32).toFixed(1)}px`);
      });
      button.addEventListener('pointerleave', () => {
        button.style.setProperty('--tx', '0px');
        button.style.setProperty('--ty', '0px');
      });
    }
  }

  function initProgress() {
    const bar = $('.progress');

    if (!bar) {
      return;
    }

    let queued = false;

    const update = () => {
      queued = false;
      const max = document.documentElement.scrollHeight - window.innerHeight;
      bar.style.transform = `scaleX(${max > 0 ? Math.min(1, window.scrollY / max).toFixed(4) : 0})`;
    };

    window.addEventListener('scroll', () => {
      if (!queued) {
        queued = true;
        requestAnimationFrame(update);
      }
    }, { passive: true });
    window.addEventListener('resize', update);
    update();
  }

  // Runs the looping animations only while their elements are on screen.
  function initLive() {
    const items = $$('.glow, .closing, .floor');

    if (!('IntersectionObserver' in window)) {
      items.forEach(item => item.classList.add('live'));
      return;
    }

    const observer = new IntersectionObserver(entries => {
      for (const entry of entries) {
        entry.target.classList.toggle('live', entry.isIntersecting);
      }
    });

    items.forEach(item => observer.observe(item));
  }

  function initTimeline() {
    const timeline = $('.timeline');

    if (!timeline) {
      return;
    }

    $$('.milestone', timeline).forEach((milestone, index) => milestone.style.setProperty('--i', index));

    if (reducedMotion || !('IntersectionObserver' in window)) {
      timeline.classList.add('drawn');
      return;
    }

    const observer = new IntersectionObserver(([entry]) => {
      if (entry.isIntersecting) {
        timeline.classList.add('drawn');
        observer.disconnect();
      }
    }, { threshold: 0.4 });

    observer.observe(timeline);
  }

  $$('pre code[class*="lang-"]').filter(code => !code.closest('#explorer-json')).forEach(paint);
  initTabs();
  initExplorer();
  initPlayground();
  addCopyButtons();
  initTyping();
  initScramble();
  initReveal();
  initNavigation();
  initSpotlight();
  initNetwork();
  initAura();
  initTilt();
  initMagnetic();
  initProgress();
  initLive();
  initTimeline();
})();
