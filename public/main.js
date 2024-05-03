$(function() {
	console.log("Main load")

	$("#quit").on("click", function() {
		$.post("/quit")
	});

	$("#settings").on("keyup", function() {
		$.post("/message", {"data": "save_settings"})
	});

	$("#scan").on("click", function() {
		$.post("/message", {"data": "scan"})
	});

	$("#copy").on("click", function() {
		$.post("/message", {"data": "copy"})
	});

});

function reset_table_listeners() {
	$("#playlists tbody tr").on("click", function() {
		console.log($(this).attr("data-id"))
		$.post("/message", {"data": "table-click", "playlist_id": $(this).attr("data-id")})
	});
}
