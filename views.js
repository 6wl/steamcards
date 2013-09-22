// prices - cheapest set to purchase
function(doc) {
  if (doc.cards.length > 0) {
    var total = 0;
    for (var i in doc.cards) {
      var price_history_length = doc.cards[i].price_history.length;
      if (price_history_length == 0 || doc.cards[i].price_history[price_history_length - 1].price == 0) {
        total = total + 99999;
      } else {
        total = total + doc.cards[i].price_history[price_history_length - 1].price;
      }
    }
    emit([total, doc.game_name], [doc.game_name, total]);
  }
}
