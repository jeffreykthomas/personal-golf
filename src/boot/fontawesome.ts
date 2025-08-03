import { boot } from 'quasar/wrappers';
import { library } from '@fortawesome/fontawesome-svg-core';
import { FontAwesomeIcon } from '@fortawesome/vue-fontawesome';

// Import specific icons you want to use
import {
  faUser,
  faHome,
  faGear,
  faEnvelope,
  faPhone,
  faHeart,
  faStar,
  faSearch,
  faPlus,
  faMinus,
  faEdit,
  faTrash,
  faSave,
  faCancel,
  faCheck,
  faTimes,
  faArrowLeft,
  faArrowRight,
  faArrowUp,
  faArrowDown,
  faSpinner,
  faExclamationTriangle,
  faInfoCircle,
  faCheckCircle,
  faTimesCircle,
} from '@fortawesome/free-solid-svg-icons';

// Add icons to the library
library.add(
  faUser,
  faHome,
  faGear,
  faEnvelope,
  faPhone,
  faHeart,
  faStar,
  faSearch,
  faPlus,
  faMinus,
  faEdit,
  faTrash,
  faSave,
  faCancel,
  faCheck,
  faTimes,
  faArrowLeft,
  faArrowRight,
  faArrowUp,
  faArrowDown,
  faSpinner,
  faExclamationTriangle,
  faInfoCircle,
  faCheckCircle,
  faTimesCircle,
);

export default boot(({ app }) => {
  // Register the Font Awesome component globally
  app.component('fa-icon', FontAwesomeIcon);
});

export { library, FontAwesomeIcon };
