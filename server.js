const express = require('express');
const bodyParser = require('body-parser');
const cors = require('cors');

const app = express();
app.use(cors());
app.use(bodyParser.json());
let bookings = [];
let isLocked = false;
const acquireLock = () => {
  return new Promise((resolve) => {
    const wait = () => {
      if (!isLocked) {
        isLocked = true;
        resolve();
      } else {
        setTimeout(wait, 10);
      }
    };
    wait();
  });
};

const releaseLock = () => {
  isLocked = false;
};


function validateBookingTime(startTime, endTime) {
  const start = new Date(startTime);
  const end = new Date(endTime);

  if (isNaN(start) || isNaN(end) || start >= end) {
    return { valid: false, message: 'Invalid startTime or endTime (check format or logical order)' };
  }
  return { valid: true };
}

function hasConflict(newStart, newEnd, excludeBookingId = null) {
  const start = new Date(newStart);
  const end = new Date(newEnd);
  return bookings.some((b) => {
    if (excludeBookingId && b.id === excludeBookingId) return false;
    const existingStart = new Date(b.startTime);
    const existingEnd = new Date(b.endTime);
    return (start < existingEnd && end > existingStart);
  });
}

app.get('/bookings', (req, res) => {
  res.json(bookings);
});

app.get('/bookings/:id', (req, res) => {
  const booking = bookings.find((b) => b.id === req.params.id);
  if (!booking) return res.status(404).json({ error: 'Booking not found' });
  res.json(booking);
});


app.post('/bookings', async (req, res) => {
  await acquireLock();

  try {
    const { userId, startTime, endTime } = req.body;
    if (!userId || !startTime || !endTime) {
      return res.status(400).json({ error: 'userId, startTime and endTime are required' });
    }

    const validation = validateBookingTime(startTime, endTime);
    if (!validation.valid) {
      return res.status(400).json({ error: validation.message });
    }

    if (hasConflict(startTime, endTime)) {
      return res.status(409).json({ error: 'Booking time conflicts with existing booking' });
    }

    const newBooking = {
      id: `booking-${Date.now()}`,
      userId,
      startTime,
      endTime,
    };

    bookings.push(newBooking);
    res.status(201).json(newBooking);
  } finally {
    releaseLock();
  }
});

app.put('/bookings/:id', async (req, res) => {
  await acquireLock();

  try {
    const bookingId = req.params.id;
    const { userId, startTime, endTime } = req.body;

    const bookingIndex = bookings.findIndex((b) => b.id === bookingId);
    if (bookingIndex === -1) return res.status(404).json({ error: 'Booking not found' });

    if (!userId || !startTime || !endTime) {
      return res.status(400).json({ error: 'userId, startTime and endTime are required' });
    }

    const validation = validateBookingTime(startTime, endTime);
    if (!validation.valid) {
      return res.status(400).json({ error: validation.message });
    }

    if (hasConflict(startTime, endTime, bookingId)) {
      return res.status(409).json({ error: 'Booking time conflicts with existing booking' });
    }

    bookings[bookingIndex] = { id: bookingId, userId, startTime, endTime };
    res.json(bookings[bookingIndex]);
  } finally {
    releaseLock();
  }
});


app.delete('/bookings/:id', (req, res) => {
  const bookingIndex = bookings.findIndex((b) => b.id === req.params.id);
  if (bookingIndex === -1) return res.status(404).json({ error: 'Booking not found' });

  const deletedBooking = bookings.splice(bookingIndex, 1)[0];
  res.json(deletedBooking);
});


const PORT = 3000;
app.listen(PORT, () => console.log(`Server running on http://localhost:${PORT}`));
