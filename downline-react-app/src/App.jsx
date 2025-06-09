import React, { useState, useEffect, createContext, useContext, useRef } from 'react';

// Firebase Imports
import { initializeApp } from 'firebase/app';
import { getAuth, signInAnonymously, signInWithCustomToken, onAuthStateChanged } from 'firebase/auth';
import { getFirestore, doc, getDoc, collection, query, where, onSnapshot, FieldPath } from 'firebase/firestore';

// Lucide React Icons for a modern look
import { ChevronDown, ChevronRight, Search, SlidersHorizontal, ArrowDownWideNarrow, Users, Network, User } from 'lucide-react';

// Context for managing the current hierarchy view and data
const DownlineContext = createContext();

// UserCard Component - Displays individual user information
const UserCard = ({ user, onClick, isExpanded, hasDownline, showDrillDownArrow = true }) => {
  return (
    <div
      className="bg-white p-4 rounded-xl shadow-md border border-gray-100 flex items-center gap-4 cursor-pointer hover:bg-gray-50 transition duration-200 ease-in-out"
      onClick={() => hasDownline && onClick(user)}
    >
      <img
        src={user.photoUrl || "https://placehold.co/100x100/A0A0A0/FFFFFF?text=?"} // Fallback if photoUrl is missing
        alt={user.firstName}
        className="w-12 h-12 rounded-full object-cover border-2 border-indigo-500"
        onError={(e) => { e.target.onerror = null; e.target.src="https://placehold.co/100x100/A0A0A0/FFFFFF?text=?" }} // Fallback on error
      />
      <div className="flex-grow">
        <h3 className="font-semibold text-lg text-gray-800">
          {user.firstName} {user.lastName} <span className="text-sm font-normal text-gray-500">Lvl {user.level}</span>
        </h3>
        <p className="text-sm text-gray-600">
          Direct: <span className="font-medium">{user.direct_sponsor_count}</span> | Team: <span className="font-medium">{user.total_team_count}</span>
        </p>
      </div>
      {showDrillDownArrow && hasDownline && (
        <span className="text-gray-500">
          {isExpanded ? <ChevronDown className="w-5 h-5" /> : <ChevronRight className="w-5 h-5" />}
        </span>
      )}
    </div>
  );
};

// DownlineTree Component (Recursive) - Renders the hierarchical structure
const DownlineTree = ({ currentUserId, allUsersMap, level = 0 }) => {
  const { pushView, popView, expandedNodes, toggleExpandNode, fetchDirectDownline, db, auth, userId } = useContext(DownlineContext);
  const user = allUsersMap.get(currentUserId);
  const [directChildren, setDirectChildren] = useState([]);
  const unsubscribeRef = useRef(null); // Ref to store the unsubscribe function

  useEffect(() => {
    // This effect fetches direct children of the current user
    // It runs when currentUserId changes or when user's referralCode changes (though latter is rare for a user)
    if (user && user.referralCode && db && auth.currentUser) {
      if (unsubscribeRef.current) {
        unsubscribeRef.current(); // Unsubscribe from previous listener
      }

      // Query for direct children: where 'referredBy' matches current user's referralCode
      const q = query(collection(db, "users"), where("referredBy", "==", user.referralCode));

      unsubscribeRef.current = onSnapshot(q, (snapshot) => {
        const children = [];
        snapshot.forEach((doc) => {
          const childData = doc.data();
          children.push(childData);
          // Also update the central allUsersMap with this child data
          fetchDirectDownline(childData); // Use a passed function to update main state
        });
        setDirectChildren(children.sort((a, b) => a.firstName.localeCompare(b.firstName)));
      }, (error) => {
        console.error("Error fetching direct downline:", error);
        // Handle error, e.g., display a message
      });
    }

    return () => {
      if (unsubscribeRef.current) {
        unsubscribeRef.current(); // Clean up on unmount or re-render
      }
    };
  }, [currentUserId, user?.referralCode, db, auth.currentUser, fetchDirectDownline]); // Depend on user's referralCode

  if (!user) return null; // Should not happen if allUsersMap is well-managed

  const hasDownline = directChildren.length > 0;
  const isExpanded = expandedNodes.includes(user.uid);

  const handleCardClick = (clickedUser) => {
    // If clicking on the root of the current view, toggle expansion
    if (clickedUser.uid === currentUserId && level === 0) {
      toggleExpandNode(clickedUser.uid);
    } else if (clickedUser.uid !== currentUserId) { // If clicking a child in the list, drill down
      pushView(clickedUser.uid);
    }
  };

  // Only render the current user's card if it's the root of the current view (level 0)
  // or if it's explicitly part of a parent's expanded direct children.
  const shouldRenderSelfCard = level === 0;

  return (
    <div className={`space-y-4 ${level > 0 ? 'pl-6 border-l-2 border-gray-200 ml-3 py-1' : ''}`}>
      {shouldRenderSelfCard && (
        <UserCard
          user={user}
          onClick={handleCardClick}
          isExpanded={isExpanded}
          hasDownline={hasDownline}
        />
      )}

      {/* Render direct children if current node is expanded (or if it's a child in a drilled-down list) */}
      {(shouldRenderSelfCard ? isExpanded : true) && hasDownline && (
        <div className="space-y-3">
          {directChildren.map(child => (
            <div key={child.uid}>
              <UserCard
                user={child}
                onClick={() => pushView(child.uid)} // Always drill down when clicking on a child's card
                hasDownline={child.downlineIds && child.downlineIds.length > 0}
                // isExpanded not relevant for children cards that are not the current view's root
                showDrillDownArrow={true} // Always show arrow for children if they have a downline
              />
            </div>
          ))}
        </div>
      )}
      {/* Message if a user has no direct downline and they are the currently viewed user */}
      {shouldRenderSelfCard && !hasDownline && user.uid === currentUserId && (
        <p className="text-gray-500 text-center py-10">This user has no direct downline members.</p>
      )}
    </div>
  );
};


// Main App Component
function App() {
  // Firebase configuration and auth global variables
  const firebaseConfig = typeof __firebase_config !== 'undefined' ? JSON.parse(__firebase_config) : null;
  const initialAuthToken = typeof __initial_auth_token !== 'undefined' ? __initial_auth_token : null;
  const appId = typeof __app_id !== 'undefined' ? __app_id : 'default-app-id'; // Use provided app ID

  // Firebase states
  const [app, setApp] = useState(null);
  const [db, setDb] = useState(null);
  const [auth, setAuth] = useState(null);
  const [userId, setUserId] = useState(null);
  const [isAuthReady, setIsAuthReady] = useState(false);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  // Application states
  const [usersData, setUsersData] = useState(new Map()); // Stores all fetched user data by UID
  const [viewStack, setViewStack] = useState([]); // Stack of UIDs for drill-down navigation
  const [expandedNodes, setExpandedNodes] = useState([]); // UIDs of currently expanded nodes in the tree view

  // Initialize Firebase and handle authentication
  useEffect(() => {
    if (!firebaseConfig) {
      setError("Firebase configuration is missing.");
      setLoading(false);
      return;
    }

    try {
      const firebaseApp = initializeApp(firebaseConfig);
      const firestoreDb = getFirestore(firebaseApp);
      const firebaseAuth = getAuth(firebaseApp);

      setApp(firebaseApp);
      setDb(firestoreDb);
      setAuth(firebaseAuth);

      const unsubscribeAuth = onAuthStateChanged(firebaseAuth, async (user) => {
        if (user) {
          setUserId(user.uid);
          setIsAuthReady(true);
          setLoading(false);
        } else {
          // If not authenticated, try to sign in with custom token or anonymously
          try {
            if (initialAuthToken) {
              await signInWithCustomToken(firebaseAuth, initialAuthToken);
            } else {
              await signInAnonymously(firebaseAuth);
            }
          } catch (authError) {
            console.error("Firebase Auth Error:", authError);
            setError(`Authentication failed: ${authError.message}`);
            setLoading(false);
          }
        }
      });

      return () => unsubscribeAuth(); // Cleanup auth listener
    } catch (initError) {
      console.error("Firebase Initialization Error:", initError);
      setError(`Failed to initialize Firebase: ${initError.message}`);
      setLoading(false);
    }
  }, [firebaseConfig, initialAuthToken]);

  // Fetch the current authenticated user's data once auth is ready
  useEffect(() => {
    if (isAuthReady && userId && db) {
      const userDocRef = doc(db, "users", userId);
      const unsubscribe = onSnapshot(userDocRef, (docSnap) => {
        if (docSnap.exists()) {
          const userData = { uid: docSnap.id, ...docSnap.data() };
          setUsersData(prev => new Map(prev).set(userData.uid, userData));
          if (viewStack.length === 0) { // Set initial view to logged-in user if not already set
            setViewStack([userData.uid]);
            setExpandedNodes([userData.uid]); // Automatically expand the root user
          }
        } else {
          console.warn("Current user document does not exist in Firestore.");
          setError("Your user profile is not found in the database. Please ensure the admin user exists.");
          // For a robust app, you might want to create a basic profile here.
        }
        setLoading(false);
      }, (error) => {
        console.error("Error fetching current user document:", error);
        setError(`Failed to fetch user profile: ${error.message}`);
        setLoading(false);
      });

      return () => unsubscribe(); // Cleanup snapshot listener
    }
  }, [isAuthReady, userId, db, viewStack.length]);

  // Function to add/update user data in the central map
  const addOrUpdateUser = (userData) => {
    setUsersData(prev => {
      const newMap = new Map(prev);
      newMap.set(userData.uid, userData);
      return newMap;
    });
  };

  // Context functions for drill-down navigation
  const pushView = (uid) => {
    setViewStack(prevStack => [...prevStack, uid]);
    setExpandedNodes(prev => [...prev.filter(id => id !== uid), uid]); // Ensure clicked node is expanded
  };

  const popView = () => {
    if (viewStack.length > 1) {
      setViewStack(prevStack => {
        const newStack = prevStack.slice(0, prevStack.length - 1);
        const poppedUid = prevStack[prevStack.length - 1];
        setExpandedNodes(prev => prev.filter(id => id !== poppedUid)); // Collapse the node we are navigating away from
        return newStack;
      });
    }
  };

  // Context function for tree expansion
  const toggleExpandNode = (uid) => {
    setExpandedNodes(prev =>
      prev.includes(uid) ? prev.filter(id => id !== uid) : [...prev, uid]
    );
  };

  // Build breadcrumbs dynamically
  const breadcrumbs = viewStack.map((uid, index) => {
    const user = usersData.get(uid);
    if (!user) return null;
    const isLast = index === viewStack.length - 1;
    return (
      <React.Fragment key={uid}>
        <span
          className={`font-medium ${isLast ? 'text-indigo-700' : 'text-gray-500 cursor-pointer hover:text-indigo-600'}`}
          onClick={() => !isLast && setViewStack(viewStack.slice(0, index + 1))}
        >
          {user.firstName} {user.lastName}
        </span>
        {!isLast && <span className="mx-2 text-gray-400">/</span>}
      </React.Fragment>
    );
  }).filter(Boolean);

  const currentViewUserId = viewStack[viewStack.length - 1];
  const currentUserInView = usersData.get(currentViewUserId);

  if (loading) {
    return (
      <div className="min-h-screen bg-gray-50 flex items-center justify-center font-sans">
        <p className="text-xl text-indigo-700">Loading application...</p>
      </div>
    );
  }

  if (error) {
    return (
      <div className="min-h-screen bg-red-50 flex items-center justify-center font-sans p-6 text-center">
        <p className="text-xl text-red-700">Error: {error}</p>
      </div>
    );
  }

  if (!isAuthReady || !userId) {
    return (
      <div className="min-h-screen bg-gray-50 flex items-center justify-center font-sans">
        <p className="text-xl text-indigo-700">Authenticating...</p>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gray-50 font-sans text-gray-800">
      {/* Tailwind CSS CDN */}
      <script src="https://cdn.tailwindcss.com"></script>
      {/* Inter Font */}
      <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap" rel="stylesheet" />
      <style>{`
        body { font-family: 'Inter', sans-serif; }
      `}</style>

      <div className="container mx-auto p-6 md:p-8 max-w-4xl">
        <h1 className="text-4xl font-bold text-center text-indigo-800 mb-6 drop-shadow-sm">Downline Report</h1>

        {/* Display Current Authenticated User ID (for multi-user app requirement) */}
        <div className="text-center text-sm text-gray-600 mb-4">
          Logged in as: <span className="font-semibold">{userId}</span>
        </div>

        {/* My Team Summary (Only show if viewing the logged-in user's root downline) */}
        {currentUserInView && viewStack.length === 1 && currentViewUserId === userId && (
          <div className="bg-gradient-to-r from-indigo-600 to-purple-700 text-white p-6 rounded-xl shadow-lg mb-8 flex flex-col sm:flex-row items-center space-y-4 sm:space-y-0 sm:space-x-6">
            <img
              src={currentUserInView.photoUrl || "https://placehold.co/100x100/A0A0A0/FFFFFF?text=?"}
              alt={currentUserInView.firstName}
              className="w-20 h-20 rounded-full object-cover border-4 border-white shadow-md"
              onError={(e) => { e.target.onerror = null; e.target.src="https://placehold.co/100x100/A0A0A0/FFFFFF?text=?" }}
            />
            <div className="text-center sm:text-left">
              <h2 className="text-3xl font-bold mb-1">
                {currentUserInView.firstName} {currentUserInView.lastName} ({currentUserInView.role})
              </h2>
              <div className="flex flex-col sm:flex-row items-center sm:space-x-4 space-y-2 sm:space-y-0">
                <p className="text-lg flex items-center">
                  <Users className="w-5 h-5 mr-2" /> Direct Sponsors: <span className="font-semibold ml-1">{currentUserInView.direct_sponsor_count}</span>
                </p>
                <p className="text-lg flex items-center">
                  <Network className="w-5 h-5 mr-2" /> Total Team: <span className="font-semibold ml-1">{currentUserInView.total_team_count}</span>
                </p>
              </div>
            </div>
          </div>
        )}

        {/* Navigation / Breadcrumbs */}
        <div className="flex items-center space-x-2 text-sm text-gray-600 mb-6 flex-wrap">
          {viewStack.length > 1 && (
            <button
              onClick={popView}
              className="flex items-center text-indigo-600 hover:text-indigo-800 transition duration-200 ease-in-out font-medium pr-2"
            >
              <ChevronRight className="w-4 h-4 rotate-180 mr-1" /> Back
            </button>
          )}
          {breadcrumbs}
        </div>

        {/* Search, Filter, Sort (Conceptual UI) */}
        <div className="bg-white p-4 rounded-xl shadow-md border border-gray-100 flex flex-col md:flex-row items-center justify-between gap-4 mb-6">
          <div className="relative w-full md:w-auto flex-grow">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400 w-5 h-5" />
            <input
              type="text"
              placeholder="Search downline members..."
              className="w-full pl-10 pr-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500 transition duration-200"
              disabled // Disable as search functionality is not implemented
            />
          </div>
          <div className="flex w-full md:w-auto justify-end gap-3">
            <button className="flex items-center gap-2 px-4 py-2 bg-indigo-500 text-white rounded-lg shadow hover:bg-indigo-600 transition duration-200" disabled>
              <SlidersHorizontal className="w-5 h-5" /> Filter
            </button>
            <button className="flex items-center gap-2 px-4 py-2 bg-indigo-500 text-white rounded-lg shadow hover:bg-indigo-600 transition duration-200" disabled>
              <ArrowDownWideNarrow className="w-5 h-5" /> Sort
            </button>
          </div>
        </div>

        {/* Downline Tree / List */}
        <div className="bg-white p-6 rounded-xl shadow-lg border border-gray-100">
          <h2 className="text-2xl font-semibold text-gray-700 mb-4">
            {currentUserInView ? `${currentUserInView.firstName} ${currentUserInView.lastName}'s Team` : 'Loading...'}
          </h2>
          <DownlineContext.Provider value={{
            db, auth, userId, // Pass Firebase instances and current user ID
            viewStack, pushView, popView,
            expandedNodes, toggleExpandNode,
            fetchDirectDownline: addOrUpdateUser // Pass the function to update central user map
          }}>
            {currentUserInView ? (
              <DownlineTree
                currentUserId={currentViewUserId}
                allUsersMap={usersData}
                level={0}
              />
            ) : (
              <p className="text-gray-500 text-center py-10">Select a user or your downline is not loaded.</p>
            )}
          </DownlineContext.Provider>
        </div>

        {/* Footer */}
        <div className="mt-8 text-center text-gray-600 text-sm">
          <p>This application fetches user data from your Firebase Firestore database.</p>
        </div>

      </div>
    </div>
  );
}

export default App;
