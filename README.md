synchronizationPerl
===================

Perl implementation of an basic application (in French) to synchronize files between two folders under Apache 2.0 license.

Compatibilité
-------------
Ce programme est écrit en Perl et est compatible avec la plupart des systèmes Linux actuels permettant l’exécution de scripts Perl.
Il est également possible d’exécuter ce programme via, par exemple, ActivePerl, ce qui permet d’exécuter celui-ci sur les environnements Windows et Mac.

ActivePerl est téléchargeable à l’adresse : http://www.activestate.com/activeperl/downloads

Utilisation
-----------
Le programme se nomme « Synchro.pl » et s’utilise de la manière suivante :
```
./Synchro.pl   Rs   Rd   D
```

Les paramètres à indiquer lors d’un appel à ce programme sont :
* **Rs** : Répertoire source à synchroniser, sous forme absolue ou relative.
* **Rd** : Répertoire de destination à synchroniser, sous forme absolue ou relative
* **D** : Intervalle de temps entre deux synchronisations, sous la forme « [[[jours:]heures:]minutes:]secondes »

Fichiers de cache
-----------------
Pour ce programme, deux fichiers de cache sont utilisés. Il s’agit des fichiers suivants :
* **.log** : Fichier de log contenant toutes les actions effectuées par le programme lors des synchronisations.
* **.statut** : Fichier de statut contenant tous les hash des fichiers finaux précédemment traités lors de la dernière synchronisation par le programme.

A noter que ceux-ci commencent par un point pour permettre, sur les systèmes Linux, d’être automatiquement cachés par le système d’exploitation. 

Fonctionnement
--------------
Si vous appelez le programme sans les paramètres obligatoires, celui-ci affichera un texte d’indication pour vous permettre de le lancer correctement, en décrivant la fonction du programme et les paramètres à passer à celui-ci pour son fonctionnement.
 
Une fois les paramètres correctement entrés, le programme effectuera des synchronisations à intervalle régulier, selon l’indication donnée en paramètre. 

Le programme va fonctionner de la manière suivante : Tout d’abord, celui-ci vérifie la validité des paramètres fournis, c’est-à-dire l’existence ou non des deux dossiers indiqués, que ces dossiers ne soient pas identiques et que l’intervalle donné est bien numérique et dans le format attendu.

Ensuite, le programme va récupérer le contenu du fichier de cache « .statut » qui lui permet de savoir, si une précédente synchronisation a été faite, quels sont les fichiers qui résultent de celle-ci. 
Par la suite, le programme récupère la liste des fichiers et dossiers du répertoire source ainsi que de celui de destination et va effectuer une fusion de type « Union » entre ces deux listes. Le programme peut dès lors parcourir chacune des entrées et vérifier les points suivants :
* Si un fichier existe dans le dossier source et celui de destination, le programme vérifie les dates de modification et si nécessaire met à jour le fichier qui ne l’est pas.
* Sinon, si un fichier/dossier existait déjà lors d’une précédente synchronisation dans un des deux répertoires (vérification grâce au fichier cache « .statut »), celui-ci est supprimé dans le répertoire qui le contient encore. Sinon, le fichier/dossier est ajouté au répertoire qui ne le contient pas encore.

Finalement, le programme met à jour le fichier de cache « .statut » et attend l’intervalle donné pour effectuer une nouvelle synchronisation. 
