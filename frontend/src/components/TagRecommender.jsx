import { useState } from 'react';
import restaurantImage from '../assets/restaurant.png';

function TagRecommender() {
  const [mode, setMode] = useState('tag');
  const [tags, setTags] = useState('');
  const [city, setCity] = useState('');
  const [userId, setUserId] = useState('');
  const [username, setUsername] = useState('');
  const [n, setN] = useState(5);
  const [results, setResults] = useState([]);
  const [userFeatures, setUserFeatures] = useState(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(false);
  const cities = [
    "Glendale Az", "Gilbert", "Phoenix", "Goodyear", "Scottsdale", "Gila Bend", "Mesa", 
    "Glendale", "Tempe", "Queen Creek", "Surprise", "Casa Grande", "Chandler", 
    "Apache Junction", "Cave Creek", "Buckeye", "Litchfield Park", "Maricopa", "Peoria", 
    "Wickenburg", "Avondale", "El Mirage", "Florence", "Tolleson", "Paradise Valley",
    "Guadalupe", "Fountain Hills", "Sun City West", "Anthem", "Ahwatukee", "Sun City", 
    "Gold Canyon", "Fort McDowell", "Laveen", "Sun Lakes", "Coolidge", "San Tan Valley", 
    "Fountain Hls", "Higley", "Carefree", "Grand Junction", "Tonopah", "Good Year", "Saguaro Lake"
  ];
  const categories = [
    "afghan", "african", "american", "asian", "bagels", "bakeries", "breakfast & brunch", "british", "buffets", 
    "burgers", "cafes", "cajun/creole", "cambodian", "candy", "caribbean", "cheese", "cheesesteaks", "chicken wings", 
    "chinese", "chocolatiers & shops", "coffee & tea", "comfort food", "creperies", "cuban", "delis", "desserts", 
    "diners", "do-it-yourself food", "donuts", "ethiopian", "ethnic food", "fast food", "festivals", "filipino", 
    "fish & chips", "fondue", "food", "food stands", "food trucks", "french", "fruits & veggies", "gelato", "german", 
    "gluten-free", "greek", "grocery", "halal", "hawaiian", "ice cream & frozen yogurt", "indian", "irish", "italian", 
    "japanese", "korean", "kosher", "laotian", "latin american", "lebanese", "live/raw food", "local flavor", 
    "mediterranean", "mexican", "middle eastern", "mongolian", "pakistani", "persian/iranian", "peruvian", "pizza", 
    "polish", "restaurants", "russian", "salad", "sandwiches", "scandinavian", "seafood", "shaved ice", "soul food", 
    "soup", "southern", "spanish", "specialty food", "steakhouses", "street vendors", "taiwanese", "tea rooms", "tex-mex", 
    "thai", "turkish", "vegan", "vegetarian", "vietnamese",
  ];
  const handleSubmit = async (e) => {
    e.preventDefault();
    setLoading(true);
    setResults([]);
    setUserFeatures(null);

    const body = { n: Number(n) };
    let url = '';

    if (mode === 'tag') {
      body.tags = tags.split(',').map(tag => tag.trim()).join(', ');
      if (city.trim()) body.city_name = city.trim();
      url = 'http://localhost:8000/recommend_by_tags';
    } else {
      body.user_id = userId;
      url = 'http://localhost:8000/recommend';
    }

    try {
      const res = await fetch(url, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(body),
      });

      const data = await res.json();
      console.log(data);
      if (mode === 'user' && data) {
        const features = await fetch(`http://localhost:8000/user_features?user_index=${userId}`);
        const featuresData = await features.json();
        let featuresDataArray = featuresData.user_features;
        setUsername(featuresData.user_name)
        if(featuresDataArray.length > 2) {
          featuresDataArray = featuresDataArray.slice(2);
        }
        setUserFeatures(featuresDataArray);
        // console.log(featuresData);
      }
      setResults(data);
      if(error) setError(false);
      if(data.error) setError(true);
    } catch (error) {
      setError(true);
      console.error('Error:', error);
    }
    setLoading(false);
  };

  return (
    <div className="bg-white shadow-md rounded-lg p-6 max-w-4xl mx-auto">
      {/* Mode Switch */}
      <div className="flex gap-4 mb-6 justify-center">
        <button
          onClick={() => setMode('tag')}
          className={`px-4 py-2 rounded ${mode === 'tag' ? 'bg-blue-600 text-white' : 'bg-gray-200'}`}
        >
          Tag Based
        </button>
        <button
          onClick={() => setMode('user')}
          className={`px-4 py-2 rounded ${mode === 'user' ? 'bg-blue-600 text-white' : 'bg-gray-200'}`}
        >
          User Based
        </button>
      </div>

      {/* Input Form */}
      <form onSubmit={handleSubmit} className="space-y-4 mb-6">
        {mode === 'tag' && (
          <>
            <input
              type="text"
              placeholder="e.g. indian, mexican"
              value={tags}
              onChange={(e) => setTags(e.target.value)}
              className="border border-gray-300 p-2 w-full rounded"
            />
            <select
              value={city}
              onChange={(e) => setCity(e.target.value)}
              className="border border-gray-300 p-2 w-full rounded"
            >
              <option value="">Select city (optional)</option>
              {cities.map((cityName) => (
                <option key={cityName} value={cityName}>{cityName}</option>
              ))}
            </select>
          </>
        )}

        {mode === 'user' && (
          <input
            type="text"
            placeholder="User ID"
            value={userId}
            onChange={(e) => setUserId(e.target.value)}
            className="border border-gray-300 p-2 w-full rounded"
          />
        )}

        <input
          type="number"
          min="1"
          value={n}
          onChange={(e) => setN(e.target.value)}
          placeholder="Number of recommendations (default 5)"
          className="border border-gray-300 p-2 w-full rounded"
        />

        <button
          type="submit"
          className="w-full bg-blue-600 hover:bg-blue-700 text-white font-semibold py-2 px-4 rounded transition"
        >
          {loading ? 'Loading...' : 'Get Recommendations'}
        </button>
      </form>

      {userFeatures && (
        <div className="mb-6 p-4 bg-blue-50 rounded-2xl border border-blue-200 shadow-sm">
          <h3 className="text-lg font-semibold text-blue-700 mb-3">User Features</h3>

          <div className="mb-2 text-sm text-blue-900">
            <span className="font-medium">Name:</span> {username}
          </div>

          <div className="flex flex-wrap gap-2 text-sm text-blue-900">
            {userFeatures.map((category, index) => (
              <span
                key={index}
                className="px-3 py-1 bg-blue-100 border border-blue-200 rounded-full"
              >
                {category}
              </span>
            ))}
          </div>
        </div>
      )}

      {/* Restaurant Cards */}
      {results.length > 0 && (
        <div className="grid sm:grid-cols-2 md:grid-cols-3 gap-6">
          {results.map((item) => (
            <div
              key={item.business_id}
              className="bg-white rounded-lg shadow hover:shadow-xl transition overflow-hidden"
            >
              <img
                src={restaurantImage}
                alt="restaurant"
                className="w-full h-40 object-cover"
              />
              <div className="p-4">
                <h2 className="text-lg font-semibold mb-1">{item.name}</h2>
                {/* <p className="text-sm text-gray-600">{item.city}, {item.state}</p> */}
                <p className="text-sm text-gray-600">{item.full_address}</p>
                <p className="text-sm mt-1"><strong>Categories:</strong> {item.categories}</p>
                <div className="mt-2 flex items-center gap-2 text-sm text-yellow-600">
                  ⭐ {Math.round(item.avg_rating * 100) / 100} ({item.review_count} reviews)
                </div>
              </div>
            </div>
          ))}
        </div>
      )}

      {loading && <p className="text-center text-gray-500">Fetching recommendations...</p>}
      {!loading && error && <p className="text-center text-gray-500">No recommendations found. Try again</p>}
    </div>
  );
}

export default TagRecommender;