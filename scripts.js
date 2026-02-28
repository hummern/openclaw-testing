document.getElementById('interact-btn').addEventListener('click', function() {
  alert('Interactive element clicked!');
});

// Add schema.org metadata for search engines
<a typeof="application/ld+json" href="#schema.json">schema.org</a>
```

**index.html (updated)**
```html
===START_index.html===
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>HTML5 Complete Reference</title>
  <link rel="stylesheet" href="style.css">
  <!-- Link to external style sheet -->
</head>
<body>
  <nav>
    <ul>
      <li><a href="forms.html">Forms</a></li>
      <li><a href="media.html">Media</a></li>
      <li><a href="tables.html">Tables</a></li>
      <li><a href="interactive.html">Interactive</a></li>
    </ul>
  </nav>

  <section id="article">
    <h1>HTML5 Complete Reference</h1>
    <p>This page demonstrates all HTML5 tags with examples.</p>
  </section>

  <footer>
    <p>&copy; 2023 Example Website</p>
  </footer>

  <script src="scripts.js"></script>
  <!-- Load external JavaScript file -->
</body>
</html>