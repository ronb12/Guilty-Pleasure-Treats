/**
 * Guilty Pleasure Treats – website interactivity
 * Mobile menu, scroll-spy nav, scroll animations, back-to-top
 */
(function () {
  'use strict';

  var header = document.querySelector('.header');
  var nav = document.querySelector('.nav');
  var navLinks = document.querySelectorAll('.nav a[href^="#"]');
  var sections = [];
  var menuToggle = null;
  var backToTop = null;

  function initMobileMenu() {
    if (!nav) return;
    menuToggle = document.getElementById('menu-toggle');
    if (!menuToggle) return;

    menuToggle.addEventListener('click', function () {
      var open = nav.classList.toggle('nav-open');
      menuToggle.setAttribute('aria-expanded', open ? 'true' : 'false');
      document.body.classList.toggle('menu-open', open);
    });

    navLinks.forEach(function (link) {
      link.addEventListener('click', function () {
        nav.classList.remove('nav-open');
        menuToggle.setAttribute('aria-expanded', 'false');
        document.body.classList.remove('menu-open');
      });
    });

    window.addEventListener('resize', function () {
      if (window.innerWidth > 768) {
        nav.classList.remove('nav-open');
        document.body.classList.remove('menu-open');
        if (menuToggle) menuToggle.setAttribute('aria-expanded', 'false');
      }
    });
  }

  function initScrollSpy() {
    sections = Array.from(navLinks).map(function (a) {
      var id = a.getAttribute('href').slice(1);
      return { id: id, section: document.getElementById(id), link: a };
    }).filter(function (s) { return s.section; });

    function updateActive() {
      var scrollY = window.scrollY || window.pageYOffset;
      var innerH = window.innerHeight;
      var threshold = innerH * 0.35;

      for (var i = sections.length - 1; i >= 0; i--) {
        var rect = sections[i].section.getBoundingClientRect();
        if (rect.top <= threshold) {
          sections.forEach(function (s) { s.link.classList.remove('nav-active'); });
          sections[i].link.classList.add('nav-active');
          return;
        }
      }
      sections.forEach(function (s) { s.link.classList.remove('nav-active'); });
    }

    window.addEventListener('scroll', function () {
      requestAnimationFrame(updateActive);
    });
    updateActive();
  }

  function initHero() {
    var hero = document.getElementById('hero');
    if (!hero) return;
    requestAnimationFrame(function () {
      requestAnimationFrame(function () {
        hero.classList.add('hero-ready');
      });
    });
  }

  function initScrollReveal() {
    var els = document.querySelectorAll('.section-label, .section h2, .section-intro, .menu-card, .order-card, .trust-strip.trust-reveal');
    var observer = new IntersectionObserver(function (entries) {
      entries.forEach(function (entry) {
        if (entry.isIntersecting) {
          entry.target.classList.add('revealed');
          observer.unobserve(entry.target);
        }
      });
    }, { rootMargin: '0px 0px -40px 0px', threshold: 0.1 });

    els.forEach(function (el) {
      if (!el.classList.contains('trust-reveal')) el.classList.add('reveal');
      observer.observe(el);
    });
  }

  function initBackToTop() {
    backToTop = document.createElement('button');
    backToTop.type = 'button';
    backToTop.setAttribute('aria-label', 'Back to top');
    backToTop.className = 'back-to-top';
    backToTop.innerHTML = '↑';
    backToTop.addEventListener('click', function () {
      window.scrollTo({ top: 0, behavior: 'smooth' });
    });
    document.body.appendChild(backToTop);

    function toggleBackToTop() {
      var show = window.scrollY > window.innerHeight;
      backToTop.classList.toggle('back-to-top-visible', show);
    }
    window.addEventListener('scroll', function () { requestAnimationFrame(toggleBackToTop); });
    toggleBackToTop();
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', run);
  } else {
    run();
  }

  function run() {
    initMobileMenu();
    initHero();
    initScrollSpy();
    initScrollReveal();
    initBackToTop();
    initScrollHint();
  }

  function initScrollHint() {
    var hint = document.querySelector('.hero-scroll-hint');
    if (!hint) return;
    function hideHint() {
      if (window.scrollY > window.innerHeight * 0.3) {
        hint.style.opacity = '0';
        hint.style.pointerEvents = 'none';
        window.removeEventListener('scroll', hideHint);
      }
    }
    window.addEventListener('scroll', hideHint);
  }
})();
