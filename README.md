## Geographic Area Creation API

This API allows users to create Geographic Areas by drawing rectangles on the map. The process involves:

1. **User Interaction:**
	 - Users can draw a rectangle by dragging on the map interface.
	 - The start and end points of the drag gesture define the rectangle's bounds.

2. **Coordinate Conversion:**
	 - The app converts the screen points to geographic coordinates (latitude/longitude).
	 - These coordinates are used to define the corners of the rectangle.

3. **Overlay Rendering:**
	 - A rectangle overlay is rendered on the map to visually indicate the selected area.
	 - The overlay uses the coordinates captured from the user's gesture.

4. **API Request:**
	 - The app sends the rectangle's coordinates to the backend API to create a new Geographic Area.
	 - The API expects a payload containing the coordinates of the rectangle's corners.

### Example API Request

```json
POST /api/geographic-areas
{
	"area": {
		"type": "rectangle",
		"coordinates": [
			{ "lat": 37.7749, "lng": -122.4194 },
			{ "lat": 37.7759, "lng": -122.4184 },
			{ "lat": 37.7769, "lng": -122.4194 },
			{ "lat": 37.7759, "lng": -122.4204 }
		]
	}
}
```

### API Response

```json
{
	"id": "area_12345",
	"type": "rectangle",
	"coordinates": [ ... ],
	"created_at": "2025-08-22T12:34:56Z"
}
```

### Notes
- The API supports other area types, but rectangle is the default for map drawing.
- The coordinates should be in order (clockwise or counterclockwise) to define the area correctly.
