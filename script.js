/* 
  This script file will use JavaScript to add interactive functionality.
*/
document.addEventListener('DOMContentLoaded', function() {
  document.getElementById('interact').addEventListener('click', function() {
    alert("You clicked the button!");
  });
});

// Add event listener for form submission
document.querySelector('form').addEventListener('submit', function(event) {
  event.preventDefault();
  
  // Get the form data
  var formData = new FormData(this);
  
  // Create a JSON object from the form data
  var jsonData = JSON.stringify(formData, null, 2);
  
  // Send the JSON object to the server or process it locally
});