
import { setGlobalOptions } from 'firebase-functions/v2';
import { REGION } from './config';

setGlobalOptions({
  region: REGION,
  maxInstances: 10,
});

export { getAvailableSlots, getAvailableDates } from './handlers/availability';

export {
  createBooking,
  adminCreateBooking,
  adminRescheduleBooking,
  adminCancelBooking,
  adminCompleteBooking,
  adminUpdateBooking,
} from './handlers/bookings';

export {
  createBookingRequest,
  resolveBookingRequest,
} from './handlers/requests';

export {
  placesAutocomplete,
  placeDetails,
} from './handlers/places';

export { sendLessonReminders } from './handlers/reminders';

// Student email invitations
export { inviteStudent } from './handlers/invitations';

export { acceptStudentTerms } from './handlers/terms';
