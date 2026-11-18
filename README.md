# xileades-surveillance

Contrôle public de disponibilité : toutes les 5 minutes, ce dépôt teste les pages publiques, leurs certificats HTTPS et la configuration de messagerie des domaines. Une panne fait échouer le contrôle, et GitHub envoie un courriel.

**Sites contrôlés** : xileades.com, projet.xileades.com.

**Base contrôlée** : xileades-website, par sa page de santé publique (`/functions/v1/sante`). Elle ne répond que « ok » ou « ko » : aucune tâche planifiée ni aucun appel sortant en erreur depuis 30 minutes. Le détail d'un « ko » ne se lit que dans les journaux de la base.

Ce dépôt est public, car les minutes de GitHub Actions y sont gratuites. Il ne contient **aucun secret** et ne vise **aucune adresse interne**. Il n'expose que des adresses déjà publiques et l'historique des contrôles.
