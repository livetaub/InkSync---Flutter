import { Link } from 'react-router-dom';
import { ArrowRight } from 'lucide-react';
import { useDocumentMetadata } from '../hooks/useDocumentMetadata';
import './NotFoundPage.css';

const NotFoundPage = () => {
  useDocumentMetadata(
    "Page Not Found — InkSync",
    "Sorry, the page you're looking for doesn't exist on InkSync."
  );

  return (
    <div className="not-found-page">
      <h1>404</h1>
      <h2>Page not found</h2>
      <p>Sorry, the page you're looking for doesn't exist or has been moved.</p>
      <Link to="/" className="btn-primary">
        Back to Home <ArrowRight size={18} />
      </Link>
    </div>
  );
};

export default NotFoundPage;
