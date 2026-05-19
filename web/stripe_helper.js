// stripe_helper.js
// ─────────────────────────────────────────────────────────────
// This file is loaded by index.html and provides the JavaScript
// bridge between Flutter (Dart) and Stripe.js.
//
// Stripe.js handles all PCI-sensitive operations (card input,
// tokenization). Raw card numbers NEVER touch our servers.
// ─────────────────────────────────────────────────────────────

let _stripe = null;
let _cardElement = null;
let _cardComplete = false;
let _cardError = '';

/// Initialize Stripe and mount the Card Element into a DOM container
function initStripeElements(publishableKey, containerId) {
  try {
    _stripe = Stripe(publishableKey);
    const elements = _stripe.elements();

    _cardElement = elements.create('card', {
      style: {
        base: {
          fontSize: '16px',
          fontFamily: '"Inter", -apple-system, BlinkMacSystemFont, sans-serif',
          fontSmoothing: 'antialiased',
          color: '#1E293B',
          '::placeholder': { color: '#94A3B8' },
          letterSpacing: '0.025em',
        },
        invalid: {
          color: '#DC2626',
          iconColor: '#DC2626',
        },
      },
      hidePostalCode: true,
    });

    const container = document.getElementById(containerId);
    if (container) {
      _cardElement.mount('#' + containerId);
    }

    // Listen for card state changes
    _cardElement.on('change', function (event) {
      _cardComplete = event.complete;
      _cardError = event.error ? event.error.message : '';
    });

    return 'ok';
  } catch (e) {
    console.error('initStripeElements error:', e);
    return 'error: ' + e.message;
  }
}

/// Create a PaymentMethod from the card input
/// Returns a JSON string: { paymentMethodId: "pm_..." } or { error: "..." }
async function createStripePaymentMethod(billingEmail, billingName) {
  if (!_stripe || !_cardElement) {
    return JSON.stringify({ error: 'Stripe not initialized' });
  }

  try {
    const { paymentMethod, error } = await _stripe.createPaymentMethod({
      type: 'card',
      card: _cardElement,
      billing_details: {
        email: billingEmail || undefined,
        name: billingName || undefined,
      },
    });

    if (error) {
      return JSON.stringify({ error: error.message });
    }

    return JSON.stringify({
      paymentMethodId: paymentMethod.id,
      brand: paymentMethod.card.brand,
      last4: paymentMethod.card.last4,
    });
  } catch (e) {
    console.error('createStripePaymentMethod error:', e);
    return JSON.stringify({ error: e.message });
  }
}

/// Check if the card input is complete and valid
function isStripeCardComplete() {
  return _cardComplete;
}

/// Get the current card error message (empty string if none)
function getStripeCardError() {
  return _cardError;
}
