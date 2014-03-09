#!/usr/bin/perl -w
#
# Programme de synchronisation entre deux répertoires
# ===================================================
# @author Chavaillaz Johan
# @date 08.05.2012
# 
# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements. See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership. The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License. You may obtain a copy of the License at
# 
# http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied. See the License for the
# specific language governing permissions and limitations
# under the License.
#
use strict;
use warnings;

use File::Path;
use File::Copy;
use File::Basename;
use File::stat;
use Digest::MD5 qw(md5 md5_hex md5_base64);

# -------------------------------------------
# Constantes du programme
# -------------------------------------------
#
# Chemins d'accès aux fichiers de log et de statut de la synchronisation
# Les fichiers seront cachés sous Linux (car ceux-ci commencent par un point)
#
use constant CHEMIN_LOG => "./.log";
use constant CHEMIN_STATUT => "./.statut";

# -------------------------------------------
# isInteger(valeur)
# -------------------------------------------
# Paramètres :
#   valeur : Valeur pour laquelle vérifier si celle-ci est un entier
#
# Valeur de retour :
#   Booléen indiquant si la valeur est un entier
#
sub isInteger 
{
	# Récupère et supprime le premier élément des paramètres de la fonction
	my $valeur = shift;
	
	# Vérifie que l'élément soit un entier 
	return ($valeur =~ m/^\d+$/);
}

# -------------------------------------------
# inArray(tableau, recherche)
# -------------------------------------------
# Paramètres :
#   tableau : Tableau dans lequel rechercher une valeur
#	recherche : Valeur à rechercher, donnée sous forme de chaine
#
# Valeur de retour :
#   Booléen indiquant si la valeur recherchée existe dans le tableau
#
sub inArray 
{
	# Récupération du tableau et de la recherche à effectuer en paramètre
    my ($tableau, $recherche) = @_;
	
	# Recherche de l'élément dans le tableau
    return grep {$recherche eq $_} @$tableau;
}

# -------------------------------------------
# trouverPosition(regex, chaine)
# -------------------------------------------
# Paramètres :
#   regex : Expression régulière à trouver dans la chaine
#	chaine : Chaine dans laquelle rechercher l'expression régulière
#
# Valeur de retour :
#   Tableau avec la position de départ comme première case 
#   et la position de fin de l'expression à la seconde case
#
sub trouverPosition 
{
	# Récupération du regex et de la chaine en paramètre
    my ($regex, $chaine) = @_;
	
	# Retourne les positons si le regex a été trouvé, sinon ne retourne rien
    return if not $chaine =~ /$regex/;
    return ($-[0], $+[0]);
}

# -------------------------------------------
# caractereChaine(chaine, numero)
# -------------------------------------------
# Paramètres :
#   chaine : Chaine dans laquelle extraire le caractère
#   numero : Position du caractère dans la chaine indiquée
#
# Valeur de retour :
#   Caractère présent dans la chaine à la position indiquée
#
sub caractereChaine 
{
    return substr $_[0], ($_[1] - 1), 1;
}

# -------------------------------------------
# slashFinal(chaine)
# -------------------------------------------
# Paramètres :
#   chaine : Chaine dans laquelle ajouter un slash finale si nécessaire
#
# Valeur de retour :
#   Chaine une fois traitée, qui se termine par un slash
#
sub slashFinal
{
	# Récupération de la chaine en paramètre
	my ($chaine) = @_;
	
	# Recherche le dernier caractère, si ce n'est pas un slash, on en ajoute un
	if (caractereChaine($chaine, length $chaine) ne '/') 
	{ 
		$chaine .= '/'; 
	}
	
	# Retourne la chaine une fois l'opération terminée
	return $chaine;
}

# -------------------------------------------
# date()
# -------------------------------------------
# Paramètres :
#   Aucun
#
# Valeur de retour :
#   Chaine contenant la date du jour avec heures, minutes et secondes
#
sub date
{
	# Récupération de la date d'aujourd'hui
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime();
	
	# Quelques corrections par rapport aux informations reçues
	$mon++;
	$year += 1900;
	
	# Renvoi de la date dans une chaine
	return "$mday/$mon/$year $hour:$min:$sec"; 
}

# -------------------------------------------
# copyPreserve(source, destination, messageErreur)
# -------------------------------------------
# Paramètres :
#   source : Adresse du fichier source à copier
#   destination : Adresse de la destination où copier le fichier source
#   messageErreur : Message d'erreur à afficher en cas de problèmes
#
# Valeur de retour :
#   Aucune
#
sub copyPreserve
{
	# Récupération des paramètres de la fonction
	my ($source, $destination, $messageErreur) = @_;
	
	# Copie du fichier source vers la destination et affichage d'un message en cas d'erreurs
	copy($source, $destination) or die $messageErreur;
	
	# Remet en place les dates d'accès et de modification au fichier copié dans destination
	utime stat($source)->atime, stat($source)->mtime, $destination;
}

# -------------------------------------------
# listeFichiers(cheminDossier, cheminBase)
# -------------------------------------------
# Paramètres :
#   cheminDossier : Chemin du dossier pour lequel récupérer ses fichiers et dossiers (en mode récursif)
#	cheminBase : Si indiqué, cette chaine sera absente de toutes les adresses de fichiers et dossiers renvoyées
#
# Valeur de retour :
#   Tableau contenant la liste des fichiers et des dossiers du répertoire ainsi que de ses sous-répertoires
#
sub listeFichiers
{
	my ($cheminDossier, $cheminBase) = @_;
	my @listeFichier = ();

	# Ouverture du répertoire indiqué en paramètre à la fonction
	opendir (my $pointeurFichier, $cheminDossier) or die "Erreur lors de l'ouverture du dossier $cheminDossier\n";
	
	# Evite la récupération des répertoires . (répertoire courant) et .. (répertoire parent)
	my @contenuDossier = grep { !/^\.\.?$/ } readdir($pointeurFichier);
	
	# Fermeture du dossier
	closedir ($pointeurFichier);
	
	# Parcours de chacun des éléments du dossier actuellement parcouru
	foreach my $element (@contenuDossier) 
	{
		# Initialise le chemin visible avec le chemin du dossier actuellement parcouru
		my $cheminVisible = $cheminDossier;
		
		# Si on ne veut pas voir apparaître le chemin de base
		if ( $cheminBase ne "" )
		{
			# Recherche la position de début et de fin du regex correspondant au dossier de base
			my @positionsBase = trouverPosition($cheminBase, $cheminDossier);
			
			# Evite l'affichage d'un slash en trop dans l'adresse
			if (caractereChaine($cheminDossier, $positionsBase[1] + 1) eq "/") { $positionsBase[1]++; }
			
			# Modifie le chemin de destination pour la mise dans le tableau
			$cheminVisible = substr $cheminDossier, $positionsBase[1];
		}
		
		# S'il s'agit d'un fichier
		if ( -f "$cheminDossier/$element" )
		{
			# Si le chemin visible du dossier n'est pas vide
			if ( $cheminVisible ne "" )
			{
				# On l'ajoute au tableau final
				push( @listeFichier, "$cheminVisible/$element" );
			}
			else
			{
				# On l'ajoute au tableau final
				push( @listeFichier, "$element" );
			}
		}
		# S'il s'agit d'un répertoire
		elsif ( -d "$cheminDossier/$element" ) 
		{
			# Appel récursif pour récupérer la liste des fichier du dossier en question
			push( @listeFichier, listeFichiers("$cheminDossier/$element", $cheminBase) );
			
			# Ajoute le dossier à la liste, mais après les fichiers des sous-répertoires
			# Ceci pour éviter un problème lors de la suppression d'un répertoire complet avant ses fichiers
			if ( $cheminVisible ne "" )
			{
				# On l'ajoute au tableau final
				push( @listeFichier, "$cheminVisible/$element" );
			}
			else
			{
				# On l'ajoute au tableau final
				push( @listeFichier, "$element" );
			}
		}
	}
	
	return @listeFichier;
}

# -------------------------------------------
# Programme principal
# -------------------------------------------

# Lancement de la commande d'effacement de l'écran selon le système d'exploitation
system $^O eq 'MSWin32' ? 'cls' : 'clear';

# Titre du programme
print STDOUT "\n  Script de synchronisation (version 1.0) :\n  =========================================\n";

# Vérification de la présence de 3 arguments au script
if (scalar(@ARGV) == 3)
{
	# Récupération du dossier source et destination passés en paramètre
	my $dossierSource = slashFinal($ARGV[0]);
	my $dossierDestination = slashFinal($ARGV[1]);
	
	# Récupération du temps entre deux synchronisations souhaité
	my @valeurTemps = split(/:/, $ARGV[2]);
	my $nombreValeurTemps = scalar(@valeurTemps);
	
	# Table de multiplication pour les secondes|minutes|heures|jours pour la transformation en secondes
	my @multiplication = (1, 60, 60*60, 60*60*24);
	
	# Variable pour le stockage du temps total d'attente en secondes
	my $tempsSeconde = 0;
	
	# Boucle de parcours des intervalles donnés
	for (my $i = 0; $i <= ($nombreValeurTemps - 1); $i++)
	{
		# Vérification que les temps indiqués soient corrects
		if ( !isInteger($valeurTemps[$nombreValeurTemps - ($i + 1)]) )
		{
			die "Un intervalle de temps indique n'est pas un entier positif";
		}
		else
		{
			# Mise à jour du temps total en seconde
			$tempsSeconde += $valeurTemps[$nombreValeurTemps - ($i + 1)] * $multiplication[$i];
		}
	}
	
	# Vérification de l'existence (et du fait que ce soit un dossier) de la source
	if ( !(-d $dossierSource) )
	{
		die "Le repertoire source n'existe pas ou n'est pas un dossier";
	}
	
	# Vérification de l'existence (et du fait que ce soit un dossier) de la destination
	if ( !(-d $dossierDestination) )
	{
		die "Le repertoire de destination n'existe pas ou n'est pas un dossier";
	}
	
	# Vérification que les deux répertoires ne sont pas identiques
	if ($dossierSource eq $dossierDestination)
	{
		die "Le repertoire source ne peut etre identique au repertoire de destination"
	}
	
	SYNCHRONISATION:
	
	# Ouverture du fichier de log en mode lecture (ajout)
	open(LOG, ">>".CHEMIN_LOG) or die "Impossible d'ouvrir ou créer le fichier de log";
	
	# Fichier contenant les différents statuts des fichiers depuis la précédente synchronisation
	my @listeStatut;
	
	# Vérification de l'existence du fichier des statuts
	if (-e CHEMIN_STATUT)
	{
		# Ouverture du fichier de statut en mode lecture
		open(STATUT, "<".CHEMIN_STATUT) or die "Impossible d'ouvrir ou créer le fichier de statut";
		
		# Enregistrement du fichier dans le tableau des statuts (1 ligne du fichier = 1 case du tableau)
		@listeStatut = <STATUT>;
		
		# Supprime les retours à la ligne dans les cases du tableau
		chomp(@listeStatut);
		
		# Fermeture du fichier de statut
		close(STATUT);
	}
	
	# Ouverture du fichier de statut en mode écriture (écrasement)
	open(STATUT, ">".CHEMIN_STATUT) or die "Impossible d'ouvrir ou créer le fichier de statut";
	
	# Récupération de la liste des fichiers des répertoires source et de destination
	my @union = listeFichiers($dossierSource, $dossierSource);
	my @fichiersDestination = listeFichiers($dossierDestination, $dossierDestination);
	
	# Union des deux tableaux contenant la liste des fichiers
	foreach my $valeur (@fichiersDestination)
	{
		# Si l'élément n'existe pas dans le tableau d'union
		if (!inArray(\@union, $valeur))
		{
			# Ajoute l'élément dans le tableau
			push(@union, $valeur);
		}
	}
	
	# Indication de synchronisation
	print STDOUT "  [".date()."] Lancement de la synchronisation\n";
	
	# Parcours de chacun des fichiers 
	foreach my $fichier (@union)
	{
		# Si le fichier existe dans le dossier source et de destination
		if ( (-e $dossierSource.$fichier) && (-e $dossierDestination.$fichier) )
		{
			# Vérification qu'il ne s'agit pas d'un dossier
			if ( !(-d $dossierSource.$fichier) && !(-d $dossierDestination.$fichier) )
			{
				# Récupératon de la date de chacun d'eux
				my $dateSource = stat($dossierSource.$fichier)->mtime;
				my $dateDestination = stat($dossierDestination.$fichier)->mtime;
				
				# Vérification de la date de chacun d'eux
				# Si le fichier source est plus récent,
				if ($dateSource > $dateDestination)
				{
					# Remplace le fichier de destination par le fichier source
					copyPreserve($dossierSource.$fichier, $dossierDestination.$fichier, "Impossible de copier le fichier $fichier de source a destination");
					
					# Ajout au fichier log
					print LOG "[".date()."] Fichier $fichier copié depuis le dossier source vers le dossier de destination\n";
				}
				elsif ($dateDestination > $dateSource)
				{
					# Remplace le fichier source par le fichier de destination
					copyPreserve($dossierDestination.$fichier, $dossierSource.$fichier, "Impossible de copier le fichier $fichier de destination a source");
					
					# Ajout au fichier log
					print LOG "[".date()."] Fichier $fichier copié depuis le dossier de destination vers le dossier source\n";
				}
			}
			
			# Ajout au fichier de statut
			print STATUT md5_hex($fichier)."\n";
		}
		else
		{
			# Variable indiquant le dossier final dans lequel mettre le fichier/dossier à supprimer/ajouter
			my $dossierFinal;
			
			# Variable indiquant le dossier de départ pour ajouter/supprimer des fichiers/dossiers
			my $dossierDepart;
			
			# Variable indiquant le type de dossier pour les logs
			my $typeDossierFinal;
			my $typeDossierDepart;
			
			# Si le fichier/dossier existe dans le dossier source
			if (-e $dossierSource.$fichier)
			{
				$dossierFinal = $dossierDestination;
				$dossierDepart = $dossierSource;
				$typeDossierFinal = "de destination";
				$typeDossierDepart = "source";
			}
			# Si le fichier/dossier existe dans le dossier de destination
			else
			{
				$dossierFinal = $dossierSource;
				$dossierDepart = $dossierDestination;
				$typeDossierFinal = "source";
				$typeDossierDepart = "de destination";
			}
			
			# Si le fichier existait depuis la dernière synchronisation
			# Cela signifie que l'utilisateur l'a supprimé
			if (inArray(\@listeStatut, md5_hex($fichier)))
			{
				# S'il s'agit d'un répertoire
				if (-d $dossierDepart.$fichier)
				{
					# Suppression du dossier
					rmdir($dossierDepart.$fichier) or die ("Impossible de supprimer le dossier $fichier dans le dossier $typeDossierDepart");
					
					# Ajout au fichier log
					print LOG "[".date()."] Dossier $fichier supprimé dans le dossier $typeDossierDepart \n";
				}
				else
				{
					# Suppression du fichier
					unlink($dossierDepart.$fichier) or die ("Impossible de supprimer le fichier $fichier dans le dossier $typeDossierDepart");
					
					# Ajout au fichier log
					print LOG "[".date()."] Fichier $fichier supprimé dans le dossier $typeDossierDepart \n";
				}
			}
			
			# Si le fichier n'existait pas depuis la dernière synchronisation
			# Cela signifie que l'utilisateur l'a ajouté	
			else
			{
				# S'il s'agit d'un répertoire à créer et qu'il n'existe pas encore dans le dossier final
				# Utilisé pour les répertoires sans fichiers devant être créés
				if ((-d $dossierDepart.$fichier) && !(-e $dossierFinal.$fichier))
				{
					# Création des répertoires
					mkpath($dossierFinal.$fichier);
					
					# Ajout au fichier log
					print LOG "[".date()."] Création du répertoire $fichier au dossier $typeDossierFinal \n";
				}
				# Sinon s'il s'agit de fichiers
				else
				{
					# Si le répertoire dans le dossier final qui doit contenir le fichier n'existe pas encore
					if ( !(-d dirname($dossierFinal.$fichier)) )
					{
						# Création des répertoires si nécessaire
						mkpath(dirname($dossierFinal.$fichier));
						
						# Ajout au fichier log
						print LOG "[".date()."] Création du/des répertoire(s) ".(dirname($dossierFinal.$fichier))." \n";
					}
					
					# Copie du fichier en préservant ses attributs de dates de modification et d'accès
					copyPreserve($dossierDepart.$fichier, $dossierFinal.$fichier, "Impossible de copier le fichier $fichier dans le dossier $typeDossierFinal \n");
					
					# Ajout au fichier log
					print LOG "[".date()."] Ajout du fichier $fichier au dossier $typeDossierFinal \n";
				}
				
				# Ajout au fichier de statut
				print STATUT md5_hex($fichier)."\n";
			}
		}
	}
	
	# Fermeture des fichiers
	close(LOG);
	close(STATUT);
	
	# Attente avant une nouvelle synchronisation
	sleep($tempsSeconde);
	goto SYNCHRONISATION;
}
else
{
  print STDOUT "  Permet de synchroniser deux repertoires (y compris les sous-repertoires) 
  en se basant sur la date et l'heure de derniere modification des fichiers.
  
  Syntaxe :  ./synchro.pl   Rs  Rd  D
    - Rs : Repertoire Source
    - Rd : Repertoire Destination
    - D : Intervalle de temps entre deux synchronisations 
          sous la forme [[[jours:]heures:]minutes:]secondes
  
  Par Johan Chavaillaz
  ";
}

