const express = require('express');
const fs = require('fs');
const bodyParser = require('body-parser');
const cors = require('cors');

const app = express();
const PORT = 3001;

app.use(bodyParser.json());
app.use(cors());

app.post('/submit', (req, res) => {
  const submission = req.body;
  console.log('Received submission:', submission);
  const data = JSON.stringify(submission) + '\n';

  fs.appendFile('submissions.txt', data, (err) => {
    if (err) {
      console.error('Error writing to file', err);
      return res.status(500).send('Internal Server Error');
    }
    res.status(200).send('Submission received');
  });
});

app.listen(PORT, () => {
  console.log(`Server is running on http://localhost:${PORT}`);
});
