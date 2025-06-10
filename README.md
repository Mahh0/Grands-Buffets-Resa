# Grands-Buffets-Resa
Petit script pour automatiser la vérif d'une dispo aux Grands Buffets de Narbonne

# Utilisation
- Tester une résa manuellement, analyser les requêtes et récupérer user-agent, x-auth-token
- Les ajouter au script
- Ajouter une url apprise si utilisation via docker sinon personnaliser le script pour utiliser autre méthode de notif
- Personnaliser les chemins
- Le fichier CSV doit contenir des lignes au format AAAA-MM-DD;soir|midi;nb_personnes
- Croner le script en reririgeant les logs dans un fichier
